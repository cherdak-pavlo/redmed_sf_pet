public class PDFGeneratorController {
    public Devices_Contract__c contract { get; private set; }
    public Stock_Address__mdt stockAddress { get; private set; }
    public List<Device__c> devices { get; private set; }
    
    public String paymentTermDate { get; private set; }
    public String deliveryTermDate { get; private set; }
    
    public PDFGeneratorController() {
        Id contractId = ApexPages.currentPage().getParameters().get('id');
        contract = [SELECT Id, Account__c, Total_Amount__c, CreatedDate, Account__r.Name, Account__r.Address__Street__s, Account__r.Address__CountryCode__s
                    FROM Devices_Contract__c 
                    WHERE Id = :contractId
                    LIMIT 1];
        
        stockAddress = [SELECT Stock_Street__c 
                        FROM Stock_Address__mdt 
                        LIMIT 1];
        
        devices = [SELECT Id, Default_Price__c, Name, Name__c
                   FROM Device__c
                   WHERE Devices_Contract__c = :contractId];
        
        paymentTermDate = Date.today().addDays(7).format();
        deliveryTermDate = Date.today().addDays(30).format();
    }
}