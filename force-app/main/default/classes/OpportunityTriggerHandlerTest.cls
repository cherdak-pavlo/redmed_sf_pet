@isTest
private class OpportunityTriggerHandlerTest {
    @TestSetup
    private static void setup() {
        Sales_Order_Item__c salesOrderItem = TestDataFactory.createSalesOrderItem(true);

        Account testAccount1 = TestDataFactory.createAccount('Test Account 1', 'APAC', true);
        Account testAccount2 = TestDataFactory.createAccount('Test Account 2', 'EMEA', true);
        
        Opportunity opp1 = TestDataFactory.createOpportunity('Test Opportunity 1', testAccount1.Id, 'Prospecting', Date.today(), true);
        Opportunity opp2 = TestDataFactory.createOpportunity('Test Opportunity 2', testAccount2.Id, 'Prospecting', Date.today(), true);
        
        Sales_Order__c salesOrder1 = TestDataFactory.createSalesOrder(testAccount1.Id, opp1.Id, true);
        Sales_Order__c salesOrder2 = TestDataFactory.createSalesOrder(testAccount2.Id, opp2.Id, true);
        
        Device__c device1 = TestDataFactory.createDevice('device1', 55000, true);
        Device__c device2 = TestDataFactory.createDevice('device2', 171825, true);
        
        Sales_Order_Item__c salesOrderItem1 = TestDataFactory.createSalesOrderItem(device1.Id, salesOrder1.Id, true);
        Sales_Order_Item__c salesOrderItem2 = TestDataFactory.createSalesOrderItem(device2.Id, salesOrder2.Id, true);

    }
    
    @isTest
    private static void testUpdateAccountTypeSuccess() {
        Id recordTypeExistingAccountId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Existing_Account' LIMIT 1
        ].Id;
        
        Opportunity opp = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
            LIMIT 1
        ];
        
        opp.Approval_Status__c = 'Approved';
        opp.StageName = 'Closed Won';
        update opp;
        
        opp = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];
        
        Account updatedAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :opp.AccountId LIMIT 1];
        
        System.assertEquals(
            'Closed Won',
            opp.StageName,
            'Opportunity should be in Closed Won stage after update.'
        );
        System.assertEquals(
            recordTypeExistingAccountId,
            updatedAccount.RecordTypeId,
            'Opportunity should have RecordType "Existing_Account" after update.'
        );
    }
    
    @isTest
    private static void testUpdateAccountTypeFailure() {        
        Id recordTypePorentialAccountId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Potential_Account' LIMIT 1
        ].Id;
        
        Opportunity opp = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
            LIMIT 1
        ];
        
        opp.Approval_Status__c = 'Approved';
        opp.StageName = 'Negotiation/Review';
        update opp;
        
        opp = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];
        
        Account currentAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :opp.AccountId LIMIT 1];
        
        System.assertEquals(
            'Negotiation/Review',
            opp.StageName,
            'Opportunity should be in Negotiation/Review stage after update.'
        );
        System.assertEquals(
            recordTypePorentialAccountId,
            currentAccount.RecordTypeId,
            'Opportunity should have RecordType "Potential_Account".'
        );
    }
    
    @isTest
    private static void testCreateDeviceContract() {
        Opportunity opp = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
            LIMIT 1
        ];
        
        opp.Approval_Status__c = 'Approved';
        opp.StageName = 'Closed Won';
        update opp;
        
        List<Devices_Contract__c> contracts = [
            SELECT Id, Account__c, Opportunity_Name__c, Total_Sales_Orders__c, Total_Sales_Orders_Items__c
            FROM Devices_Contract__c
            WHERE Opportunity_Name__c = :opp.Id
        ];
        
        Devices_Contract__c createdContract = contracts[0];
        
        System.assertEquals(1, contracts.size(), 'There should be one Devices_Contract created.');
        System.assertEquals(opp.AccountId, createdContract.Account__c, 'The contract should be associated with the correct Account.');
        System.assertEquals(1, createdContract.Total_Sales_Orders__c, 'The contract should have the correct number of sales orders.');
        System.assertEquals(1, createdContract.Total_Sales_Orders_Items__c, 'The contract should have the correct total devices included.');
    }

    @isTest
    private static void testBulkCreateDeviceContract() {
        List<Opportunity> opportunities = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
        ];
        
        for (Opportunity opp : opportunities) {
            opp.Approval_Status__c = 'Approved';
            opp.StageName = 'Closed Won';
        }
        
        update opportunities;
            
        List<Devices_Contract__c> contracts = [
            SELECT Id, Account__c, Opportunity_Name__c, Total_Sales_Orders__c, Total_Sales_Orders_Items__c
            FROM Devices_Contract__c
        ];

        System.assertEquals(3, contracts.size(), 'There should be two Devices_Contract created.');
        
        for (Devices_Contract__c createdContract : contracts) {
            System.assertEquals(1, createdContract.Total_Sales_Orders__c, 'The contract should have the correct number of sales orders.');
            System.assertEquals(1, createdContract.Total_Sales_Orders_Items__c, 'The contract should have the correct total devices included.');
        }
    }
    
    @isTest
    private static void testUpdateDeviceRecordsAndOrder() {
        List<Opportunity> opportunities = [
            SELECT Id, StageName, AccountId
            FROM Opportunity
        ];
        
        for (Opportunity opp : opportunities) {
            opp.Approval_Status__c = 'Approved';
            opp.StageName = 'Closed Won';
        }
        
        Test.startTest();
        update opportunities;
        Test.stopTest();
        
        List<Sales_Order__c> salesOrders = [
            SELECT Id 
            FROM Sales_Order__c 
            WHERE Opportunity__c IN :opportunities
        ];
        
        List<Id> salesOrderIds = new List<Id>();
        for (Sales_Order__c order : salesOrders) {
            salesOrderIds.add(order.Id);
        }
        
        List<Sales_Order_Item__c> salesOrderItems = [
            SELECT Device__c 
            FROM Sales_Order_Item__c 
            WHERE Sales_Order__c IN :salesOrderIds
        ];

        List<Id> salesOrderItemIds = new List<Id>();
        for (Sales_Order_Item__c item : salesOrderItems) {
            salesOrderItemIds.add(item.Device__c);
        }
        
        List<Device__c> updatedDevices = [
            SELECT Id, Status__c, Devices_Contract__c, Account__c 
            FROM Device__c 
            WHERE Id IN :salesOrderItemIds
        ];
        
        for (Device__c device : updatedDevices) {
            System.assertEquals('Sold', device.Status__c, 'Device field "Status__c" must be "Sold"');
            System.assertNotEquals(null, device.Devices_Contract__c, 'Device must be filled "Devices_Contract__c" field');
            System.assertNotEquals(null, device.Account__c, 'Device must be filled "Account__c" field');
        }
        
        List<Sales_Order__c> updatedSalesOrders = [
            SELECT Id, Devices_Contract__c, Sold_to__c 
            FROM Sales_Order__c 
            WHERE Opportunity__c IN :opportunities
        ];
        
        for (Sales_Order__c order : updatedSalesOrders) {
            System.assertNotEquals(null, order.Devices_Contract__c, 'SalesOrder must be filled "Devices_Contract__c" field');
            System.assertNotEquals(null, order.Sold_to__c, 'SalesOrder must be filled "Sold_to__c" field');
        }
    }
}