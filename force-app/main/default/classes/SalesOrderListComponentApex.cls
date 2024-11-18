public with sharing class SalesOrderListComponentApex {
    @AuraEnabled
    public static Map<String, Object> getSalesOrders(Id opportunityId, Integer offsetValue) {
        Integer limitSize = 2;

        List<Sales_Order__c> salesOrders = [
            SELECT Id, Name, Total_Amount__c, Discount__c, Total_Devices_Included__c,
            (SELECT Id, Name, Discount__c, Total_Amount__c FROM Sales_Order_Items__r)
            FROM Sales_Order__c 
            WHERE Opportunity__c = :opportunityId
            LIMIT :limitSize OFFSET :offsetValue
        ];
        
        Boolean hasMoreOrders = [
            SELECT COUNT() 
            FROM Sales_Order__c 
            WHERE Opportunity__c = :opportunityId
        ] > offsetValue + limitSize;

        return new Map<String, Object>{
            'salesOrders' => salesOrders,
            'hasMoreOrders' => hasMoreOrders
        };
    }
}