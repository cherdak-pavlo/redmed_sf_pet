({
    doInit : function(component, event, helper) {
        helper.loadSalesOrders(component);
    },
    
    handlePrevious : function(component, event, helper) {
        const offset = component.get("v.offsetValue");
        component.set("v.offsetValue", offset - 2);
        helper.loadSalesOrders(component);
    },
    
    handleNext : function(component, event, helper) {
        const offset = component.get("v.offsetValue");
        component.set("v.offsetValue", offset + 2);
        helper.loadSalesOrders(component);
    },
})