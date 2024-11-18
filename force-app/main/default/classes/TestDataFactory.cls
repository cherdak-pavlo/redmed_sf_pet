@isTest
public class TestDataFactory {
    public static Account createAccount(Boolean doInsert) {
        return createAccount('testAccount', 'APAC', doInsert);
    }

    public static Account createAccount(String name, String region, Boolean doInsert) {
        Id potentialAccountRecordTypeId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Potential_Account' LIMIT 1
        ].Id;

		Account acc = new Account();
        acc.Name = name;
        acc.RecordTypeId = potentialAccountRecordTypeId;
        acc.Region__c = region;

		if (doInsert) {
			insert acc;
		}

		return acc;
	}
    
    public static Device__c createDevice(Boolean doInsert) {
        return createDevice('testDevice', 50000, doInsert);
    }
    
    public static Device__c createDevice(String name, Integer price, Boolean doInsert) {
        Id inStockRecordTypeId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Device__c' AND DeveloperName = 'In_Stock' LIMIT 1
        ].Id;
        
        Device__c device = new Device__c();
		device.Name__c = name;
        device.RecordTypeId = inStockRecordTypeId;
        device.Default_Price__c = price;

        if (doInsert) {
			insert device;
		}

		return device;
    }
    
    public static Opportunity createOpportunity(Boolean doInsert) {
        Account acc = createAccount(true);
        return createOpportunity('testOpportunity', acc.Id, 'Prospecting', Date.today().addDays(14), doInsert);
    }

	public static Opportunity createOpportunity(
        String name, Id accountId, String stageName, Date closeDate, Boolean doInsert
    ) {
        Opportunity opp = new Opportunity();
        opp.Name = name;
        opp.AccountId = accountId;
        opp.StageName = stageName;
        opp.CloseDate = closeDate;

        if (doInsert) {
            insert opp;
        }

        return opp;
    }
    
    public static Sales_Order__c createSalesOrder(Boolean doInsert) {
        Opportunity opp = createOpportunity(true);
        return createSalesOrder(opp.AccountId, opp.Id, doInsert);
    }

	public static Sales_Order__c createSalesOrder(Id accountId, Id oppId, Boolean doInsert) {
        Sales_Order__c salesOrder = new Sales_Order__c();
        salesOrder.Sold_to__c = accountId;
        salesOrder.Opportunity__c = oppId;

        if (doInsert) {
            insert salesOrder;
        }

        return salesOrder;
    }
    
    public static Sales_Order_Item__c createSalesOrderItem(Boolean doInsert) {
        Device__c device = createDevice(true);
        Sales_Order__c salesOrder = createSalesOrder(true);
        return createSalesOrderItem(device.Id, salesOrder.Id, doInsert);
    }
    
    public static Sales_Order_Item__c createSalesOrderItem(Id deviceId, Id salesOrder, Boolean doInsert) {
        Sales_Order_Item__c salesOrderItem = new Sales_Order_Item__c();
        salesOrderItem.Device__c = deviceId;
        salesOrderItem.Sales_Order__c = salesOrder;
        
        if (doInsert) {
            insert salesOrderItem;
        }

        return salesOrderItem;
    }
}