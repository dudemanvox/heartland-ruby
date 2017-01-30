module Hps
  class HpsBatchService < HpsService
    
    def close_batch()
      
      xml = Builder::XmlMarkup.new
      
      xml.hps :Transaction do
        xml.hps :BatchClose, "BatchClose"
      end
      
      response = doTransaction(xml.target!)
      header = response["Header"]

      unless header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end

      batch_close = response["Transaction"]["BatchClose"]
      result = HpsBatch.new()
      result.id = batch_close["BatchId"]
      result.sequence_number = batch_close["BatchSeqNbr"]
      result.total_amount = batch_close["TotalAmt"]
      result.transaction_count = batch_close["TxnCnt"]
      
      result
    end

    def batch_details(batch_id = nil)

      xml = Builder::XmlMarkup.new

      xml.hps :Transaction do
        xml.hps :ReportBatchDetail do
          if batch_id.present?
            xml.hps :BatchId, batch_id.to_s
          end
        end
      end

      response = doTransaction(xml.target!)
      header = response["Header"]

      unless header["GatewayRspCode"].eql? "0"
        raise @exception_mapper.map_gateway_exception(header["GatewayTxnId"], header["GatewayRspCode"], header["GatewayRspMsg"])
      end

      batch_summary = response["Transaction"]["ReportBatchDetail"]["Header"]
      batch_details = response["Transaction"]["ReportBatchDetail"]["Details"]
      batch_details = batch_details.kind_of?(Array) ? batch_details : [batch_details]
      result = HpsBatchDetails.new
      result.status = batch_summary["BatchStatus"]
      result.id = batch_summary["BatchId"]
      result.sequence_number = batch_summary["BatchSeqNbr"]
      result.total_amount = batch_summary["BatchTxnAmt"]
      result.transaction_count = batch_summary["BatchTxnCnt"]
      
      result.transactions = batch_details.map do |txn|
        txn_response_code = txn["RspCode"]
        detail = HpsReportTransactionDetails.new(hydrate_transaction_header(header))
        detail.transaction_id = header["GatewayTxnId"]
        detail.original_transaction_id = txn["OriginalGatewayTxnId"]
        detail.authorized_amount = txn["AuthAmt"]
        detail.authorization_code = txn["AuthCode"]
        detail.avs_result_code = txn["AVSRsltCode"]
        detail.card_type = txn["CardType"]
        detail.masked_card_number = txn["MaskedCardNbr"]
        detail.transaction_type = Hps.service_name_to_transaction_type(txn["ServiceName"])
        detail.transaction_date = txn["TxnUtcDT"]
        detail.cvv_result_code = txn["CVVRsltCode"]
        detail.response_code = txn["RspCode"]
        detail.response_text = txn["RspText"]
        
        if txn_response_code != "00"
          message = txn["RspText"]
          exceptions = HpsChargeExceptions.new()
          exceptions.card_exception = @exception_mapper.map_issuer_exception(header["GatewayTxnId"], txn_response_code, message)
        end

        detail.exceptions = exceptions
        detail
      end

      result
    end
    
  end
end