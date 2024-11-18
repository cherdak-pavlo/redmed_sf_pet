({
    loadSalesOrders  : function(component) {
        const opportunityId = component.get("v.recordId");
        const offsetValue = component.get("v.offsetValue");
        const action = component.get("c.getSalesOrders");
        
        action.setParams({
            opportunityId: opportunityId,
            offsetValue: offsetValue
        });
        
        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const result = response.getReturnValue();
                
                component.set("v.salesOrders", result.salesOrders);
                component.set("v.isFirstPage", offsetValue === 0);
                component.set("v.isLastPage", !result.hasMoreOrders);
            } else {
                console.error("Error fetching sales orders: " + response.getError());
            }
        });
        
        $A.enqueueAction(action);
    }
})