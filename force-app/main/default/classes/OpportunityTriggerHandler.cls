public with sharing class OpportunityTriggerHandler {
    public void run() {
        if (Trigger.isUpdate && Trigger.isAfter) {
            UpdateAccountType(Trigger.new);
            CreateDeviceContract(Trigger.new, (Map<Id, Opportunity>)Trigger.oldMap);
            UpdateDeviceRecordsAndOrder(Trigger.new, (Map<Id, Opportunity>)Trigger.oldMap);
        }
    }
    
    private void UpdateAccountType(List<Opportunity> triggerNew) {
        Map<String, Id> accountRecordTypes = new Map<String, Id>();
        Set<Id> accountIds = new Set<Id>();
        List<Account> accountsToUpdate = new List<Account>();
        
        for (RecordType recordType : [
            SELECT Id, DeveloperName
            FROM RecordType 
            WHERE SObjectType = 'Account' AND DeveloperName IN ('Potential_Account', 'Existing_Account') 
        ]) {
            accountRecordTypes.put(recordType.DeveloperName, recordType.Id);
        }
        
        for (Opportunity opp : triggerNew) {
            if (opp.StageName == 'Closed Won' && opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        List<Account> accountsInfoForUpdate = [
            SELECT Id, RecordTypeId FROM Account WHERE Id IN :accountIds
        ];
        
        for (Account acc : accountsInfoForUpdate) {
            if (acc.RecordTypeId == accountRecordTypes.get('Potential_Account')) {
                acc.RecordTypeId = accountRecordTypes.get('Existing_Account');
                accountsToUpdate.add(acc);
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
    
    private void CreateDeviceContract(List<Opportunity> triggerNew, Map<Id, Opportunity> triggerOldMap) {
        Map<Id, Id> accountAndOpportunityIds = new Map<Id, Id>();
        Map<Id, Integer> salesOrderCount = new Map<Id, Integer>();
        Map<Id, Decimal> salesOrderItemsCount = new Map<Id, Decimal>();
        List<Devices_Contract__c> contractsToCreate = new List<Devices_Contract__c>();

        for (Opportunity opp : triggerNew) {
            Opportunity oldOpp = triggerOldMap.get(opp.Id);

            if (opp.StageName == 'Closed Won' && opp.AccountId != null && oldOpp.StageName != 'Closed Won')  {
                accountAndOpportunityIds.put(opp.Id, opp.AccountId);
            }
        }

        if (accountAndOpportunityIds.isEmpty()) {
            return;
        }

        List<Sales_Order__c> salesOrders = [
            SELECT Opportunity__c, Total_Devices_Included__c
            FROM Sales_Order__c
            WHERE Opportunity__c IN :accountAndOpportunityIds.keySet()
        ];
        
        for (Sales_Order__c salesOrder : salesOrders) {
            Id oppId = salesOrder.Opportunity__c;

            if (!salesOrderCount.containsKey(oppId)) {
                salesOrderCount.put(oppId, 0);
            }
            salesOrderCount.put(oppId, salesOrderCount.get(oppId) + 1);

            if (!salesOrderItemsCount.containsKey(oppId)) {
                salesOrderItemsCount.put(oppId, 0);
            }
            salesOrderItemsCount.put(oppId, salesOrderItemsCount.get(oppId) + salesOrder.Total_Devices_Included__c);
        }
        
        for (Id oppId : accountAndOpportunityIds.keySet()) {
            Devices_Contract__c newContract = new Devices_Contract__c();
            newContract.Account__c = accountAndOpportunityIds.get(oppId);
            newContract.Opportunity_Name__c = oppId;
            newContract.Total_Sales_Orders__c = salesOrderCount.get(oppId);
            newContract.Total_Sales_Orders_Items__c = salesOrderItemsCount.get(oppId);

            contractsToCreate.add(newContract);
        }
        
        if (!contractsToCreate.isEmpty()) {
            insert contractsToCreate;
        }
    }
    
    private void UpdateDeviceRecordsAndOrder(List<Opportunity> triggerNew, Map<Id, Opportunity> triggerOldMap) {
        Id soldRecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Sold' AND SObjectType = 'Device__c' LIMIT 1].Id;

        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
		Map<Id, Id> opportunityToAccountMap = new Map<Id, Id>();

        for (Opportunity opp : triggerNew) {
            Opportunity oldOpp = triggerOldMap.get(opp.Id);
            
            if (opp.StageName == 'Closed Won' && opp.AccountId != null && oldOpp.StageName != 'Closed Won') {
                opportunityIds.add(opp.Id);
                accountIds.add(opp.AccountId);
                opportunityToAccountMap.put(opp.Id, opp.AccountId);
            }
        }
        
        if (opportunityIds.isEmpty()) {
            return;
        }
        
        Map<Id, Id> opportunityToContractMap = new Map<Id, Id>();

        List<Devices_Contract__c> contracts = [
            SELECT Id, Opportunity_Name__c 
            FROM Devices_Contract__c 
            WHERE Opportunity_Name__c IN :opportunityIds
        ];

        for (Devices_Contract__c contract : contracts) {
            opportunityToContractMap.put(contract.Opportunity_Name__c, contract.Id);
        }

        List<Sales_Order__c> salesOrdersToUpdate = new List<Sales_Order__c>();
        
        List<Sales_Order__c> salesOrders = [
            SELECT Id, Opportunity__c, Devices_Contract__c 
            FROM Sales_Order__c 
            WHERE Opportunity__c IN :opportunityIds
        ];
        
        for (Sales_Order__c salesOrder : salesOrders) {
            Id contractId = opportunityToContractMap.get(salesOrder.Opportunity__c);
            if (contractId != null) {
                salesOrder.Last_Updated_By_Trigger__c = System.now();
                salesOrder.Devices_Contract__c = contractId;

                Id accountId = opportunityToAccountMap.get(salesOrder.Opportunity__c);
                if (accountId != null) {
                    salesOrder.Sold_to__c = accountId;
                }
                
                salesOrdersToUpdate.add(salesOrder);
            }
        }
        
        if (salesOrdersToUpdate.isEmpty()) {
            return;
        }
        
        List<Sales_Order_Item__c> orderItems = [
            SELECT Id, Device__c, Sales_Order__c
            FROM Sales_Order_Item__c 
            WHERE Sales_Order__c IN :salesOrdersToUpdate
        ];
        
        Set<Id> deviceIds = new Set<Id>();
        Map<Id, Id> salesOrderToContractMap = new Map<Id, Id>();
        
        for (Sales_Order__c salesOrder : salesOrdersToUpdate) {
            salesOrderToContractMap.put(salesOrder.Id, salesOrder.Devices_Contract__c);
        }
        
        Map<Id, Id> deviceContractToAccountMap = new Map<Id, Id>();
        
        List<Devices_Contract__c> devicesContracts = [
            SELECT Id, Account__c 
            FROM Devices_Contract__c 
            WHERE Opportunity_Name__c IN :opportunityIds
        ];
        
        for (Devices_Contract__c contract : devicesContracts) {
            deviceContractToAccountMap.put(contract.Id, contract.Account__c);
        }
        
        for (Sales_Order_Item__c item : orderItems) {
            if (item.Device__c != null) {
                deviceIds.add(item.Device__c);
            }
        }
        
        if (deviceIds.isEmpty()) {
            return;
        }
        
        Map<Id, Account> accountsMap = new Map<Id, Account>([
            SELECT Id, Address__City__s, Address__CountryCode__s, Address__Street__s, Address__PostalCode__s
            FROM Account
            WHERE Id IN :accountIds
        ]);
        
        List<Device__c> devicesToUpdate = [
            SELECT Id, RecordTypeId, Status__c, Account__c, Devices_Contract__c, Stock_Address__c 
            FROM Device__c 
            WHERE Id IN :deviceIds
        ];
        
        for (Device__c device : devicesToUpdate) {
            for (Sales_Order_Item__c item : orderItems) {
                if (item.Device__c == device.Id) {
                    Id deviceContractId = salesOrderToContractMap.get(item.Sales_Order__c);
                    device.Devices_Contract__c = deviceContractId;
                    device.Account__c = deviceContractToAccountMap.get(deviceContractId);

                    Account account = accountsMap.get(device.Account__c);
                    device.Address_to_Deliver__City__s = account.Address__City__s;
                    device.Address_to_Deliver__CountryCode__s = account.Address__CountryCode__s;
                    device.Address_to_Deliver__Street__s = account.Address__Street__s;
                    device.Address_to_Deliver__PostalCode__s = account.Address__PostalCode__s;

                    break;
                }
            }
            device.RecordTypeId = soldRecordTypeId;
            device.Status__c = 'Sold';
        }
        
        if (!devicesToUpdate.isEmpty()) {
            update devicesToUpdate;
            update salesOrdersToUpdate;
        }
    }
}