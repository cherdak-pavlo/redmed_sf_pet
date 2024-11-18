public with sharing class NewSalesOrderController {
    @AuraEnabled
    public static List<Device__c> getDevices() {
        try {
            List<Device__c> devices = [
                SELECT Id, Name, Name__c, Default_Price__c
                FROM Device__c
                WHERE
                    RecordType.DeveloperName = 'In_Stock'
                    AND Order_Is_Pending__c = FALSE
                WITH SECURITY_ENFORCED
            ];

            return devices;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createOrderWithItems(
        Id opportunityId,
        Decimal discount,
        List<Map<String, Object>> deviceDetails
    ) {
        try {
            Sales_Order__c salesOrder = new Sales_Order__c(
                Opportunity__c = opportunityId,
                Discount__c = (discount > 0 ? discount : null)
            );

            if (Schema.sObjectType.Sales_Order__c.isCreateable()) {
                insert salesOrder;
            } else {
                System.debug('User does not have access to create a Sales Order record');
            }

            List<Sales_Order_Item__c> salesOrderItems = new List<Sales_Order_Item__c>();

            for (Map<String, Object> deviceDetail : deviceDetails) {
                Id deviceId = (Id) deviceDetail.get('deviceId');
                Decimal deviceDiscount = (Decimal) deviceDetail.get('discount');

                Sales_Order_Item__c orderItem = new Sales_Order_Item__c(
                    Sales_Order__c = salesOrder.Id,
                    Device__c = deviceId,
                    Discount__c = (deviceDiscount > 0 ? deviceDiscount : null)
                );

                salesOrderItems.add(orderItem);
            }

            if (!salesOrderItems.isEmpty()) {
                if (Schema.sObjectType.Sales_Order_Item__c.isCreateable()) {
                    insert salesOrderItems;
                } else {
                    System.debug('User does not have access to create a Sales Order record');
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}