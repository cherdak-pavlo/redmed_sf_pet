import { LightningElement, track, api } from 'lwc';
import getDevices from '@salesforce/apex/NewSalesOrderController.getDevices';
import createOrderWithItems from '@salesforce/apex/NewSalesOrderController.createOrderWithItems';
import { RefreshEvent } from "lightning/refresh";

export default class NewSalesOrder extends LightningElement {
    @api recordId;
    @track devices = [];
    @track selectedIds = [];
    @track device_details = [];
    isError = false;
    isTableError = false;
    discount = null;
    showForm = false;
    creatingOrderInProcess = false;
    orderWasCreated = false;

    filter = {
        criteria: [
            {
                fieldPath: 'Id',
                operator: 'nin',
                value: this.selectedIds
            },
            {
                fieldPath: 'RecordType.DeveloperName',
                operator: 'eq',
                value: 'In_Stock'
            },
            {
                fieldPath: 'Order_Is_Pending__c',
                operator: 'eq',
                value: false
            }
        ]
    };

    displayInfo = {
        primaryField: 'Name__c',
        additionalFields: ['Name']
    };

    matchingInfo = {
        primaryField: { fieldPath: 'Name__c' },
        additionalFields: [{ fieldPath: 'Name' }]
    };

    async handleNewOrderClick() {
        try {
            this.orderWasCreated = false;
            this.devices = await getDevices();
            this.showForm = true;
        } catch (error) {
            console.log(error);
        }
    }
    

    handleCancelClick() {
        this.showForm = false;
        this.device_details = [];
        this.devices = [];
        this.discount = null;
        this.isTableError = false;
        this.isError = false;

        if (!this.creatingOrderInProcess) {
            this.selectedIds = [];
        }

        const criteriaReference = this.filter.criteria.find(
            (el) => el.fieldPath === 'Id' && el.operator === 'nin'
        );

        if (criteriaReference) {
            criteriaReference.value = this.selectedIds;
        }
    }

    handleDiscountChange(event) {
        let value = event.target.value;

        if (value < 0 || value > 99) {
            this.isError = true;
            value = null;
        } else {
            this.isError = false;
        }

        this.discount = value;
    }

    handleChange(event) {
        const selectedRecordId = event.detail.recordId;

        if (selectedRecordId) {
            this.selectedIds.push(selectedRecordId);
            this.template
                .querySelector('lightning-record-picker')
                .clearSelection();

            const selected_device = this.devices.find(
                (device) => device.Id === selectedRecordId
            );

            if (selected_device) {
                this.device_details.push({
                    ...selected_device,
                    Discount: null,
                    Amount: selected_device.Default_Price__c
                });
            }
        }
    }

    handleChangeDeviceDiscount(event) {
        const discountValue = event.target.value;
        const deviceId = event.target.dataset.id;
        const device = this.device_details.find((el) => el.Id === deviceId);

        if (device) {
            if (discountValue >= 0 && discountValue < 100) {
                device.Discount = Number(discountValue);
                device.Amount =
                    device.Default_Price__c -
                    device.Default_Price__c * (discountValue / 100);
                device.hasError = false;
            } else {
                device.Discount = null;
                device.hasError = true;
                device.Amount = device.Default_Price__c;
            }

            this.isTableError = this.device_details.some((el) => el.hasError);
            this.device_details = [...this.device_details];
        }
    }

    async handleCreateNewOrder() {
        if (
            this.isError &&
            this.isTableError &&
            this.device_details.length < 1 &&
            !this.recordId
        ) {
            return;
        }

        try {
            this.creatingOrderInProcess = true;

            const deviceDetails = this.device_details.map((device) => ({
                deviceId: device.Id,
                discount: device.Discount
            }));

            await createOrderWithItems({
                opportunityId: this.recordId,
                discount: this.discount,
                deviceDetails
            });

            this.orderWasCreated = true;
            this.handleCancelClick();
        } catch (error) {
            console.log('Error => ', error);
        } finally {
            this.creatingOrderInProcess = false;
            this.dispatchEvent(new RefreshEvent());
        }
    }

    handleDeviceDetailClick(event) {
        event.preventDefault();
        const deviceId = event.target.dataset.id;
        const recordUrl = `/lightning/r/Device__c/${deviceId}/view`;
        window.open(recordUrl, '_blank');
    }

    get errorOrNot() {
        return this.isError
            ? 'slds-form-element__control slds-has-error'
            : 'slds-form-element__control';
    }

    get availableDevices() {
        return this.devices.length - this.device_details.length;
    }

    get total_amount() {
        const baseAmount = this.device_details.reduce((total, device) => {
            const deviceDiscount = device.Discount || 0;
            const discountedPrice =
                device.Default_Price__c -
                (device.Default_Price__c * deviceDiscount) / 100;
            return total + discountedPrice;
        }, 0);

        return baseAmount - (baseAmount * this.discount) / 100;
    }

    get isCreateOrderButtonDisabled() {
        return (
            this.isError ||
            this.isTableError ||
            this.device_details.length < 1 ||
            this.creatingOrderInProcess
        );
    }
}