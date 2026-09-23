import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getSetupStatus from '@salesforce/apex/SetupWizardController.getSetupStatus';
import assignAutomationPermSet from '@salesforce/apex/SetupWizardController.assignAutomationPermSet';
import getAvailableUsers from '@salesforce/apex/SetupWizardController.getAvailableUsers';
import assignUserPermSets from '@salesforce/apex/SetupWizardController.assignUserPermSets';
import saveApiKey from '@salesforce/apex/SetupWizardController.saveApiKey';

export default class SetupWizard extends LightningElement {
    status = null;
    error = null;
    _wiredStatusResult;
    availableUsers = [];
    selectedUsers = [];
    loading = true;
    assigningAutomation = false;
    assigningUsers = false;
    showUserSelection = false;
    loadingUsers = false;
    apiKeyInput = '';
    savingApiKey = false;
    editingApiKey = false;

    @wire(getSetupStatus)
    wiredStatus(result) {
        this._wiredStatusResult = result;
        if (result.data) {
            this.status = result.data;
            this.error = null;
            this.loading = false;
        } else if (result.error) {
            this.error = result.error;
            this.status = null;
            this.loading = false;
        }
    }

    get hasError() {
        return !this.loading && this.error != null;
    }

    get hasStatus() {
        return !this.loading && this.status != null;
    }

    get automationIconName() {
        if (!this.status) return 'utility:close';
        return this.status.automationPermSetAssigned ? 'utility:success' : 'utility:close';
    }

    get automationIconVariant() {
        if (!this.status) return 'error';
        return this.status.automationPermSetAssigned ? 'success' : 'error';
    }

    get siteIconName() {
        if (!this.status) return 'utility:close';
        return this.status.siteActive ? 'utility:success' : 'utility:close';
    }

    get siteIconVariant() {
        if (!this.status) return 'error';
        return this.status.siteActive ? 'success' : 'error';
    }

    get siteDescription() {
        if (this.status && this.status.siteActive && this.status.siteUrl) {
            return 'Site is active at ' + this.status.siteUrl;
        }
        return 'Activate the ObjProof site to enable the callback endpoint for receiving AI scoring results.';
    }

    get userIconName() {
        if (!this.status) return 'utility:close';
        return this.status.usersWithPermSet > 0 ? 'utility:success' : 'utility:close';
    }

    get userIconVariant() {
        if (!this.status) return 'error';
        return this.status.usersWithPermSet > 0 ? 'success' : 'error';
    }

    get userCountLabel() {
        var count = this.status ? this.status.usersWithPermSet : 0;
        if (!count) count = 0;
        return count + ' user' + (count !== 1 ? 's' : '') + ' currently assigned';
    }

    get apiKeyIconName() {
        if (!this.status) return 'utility:close';
        return this.status.apiKeyConfigured ? 'utility:success' : 'utility:close';
    }

    get apiKeyIconVariant() {
        if (!this.status) return 'error';
        return this.status.apiKeyConfigured ? 'success' : 'error';
    }

    get showApiKeyInput() {
        return this.status && (!this.status.apiKeyConfigured || this.editingApiKey);
    }

    get saveApiKeyDisabled() {
        return this.savingApiKey || !this.apiKeyInput || !this.apiKeyInput.trim();
    }

    get completedSteps() {
        if (!this.status) return 0;
        var count = 0;
        if (this.status.automationPermSetAssigned) count++;
        if (this.status.siteActive) count++;
        if (this.status.apiKeyConfigured) count++;
        if (this.status.usersWithPermSet > 0) count++;
        return count;
    }

    get progressLabel() {
        return this.completedSteps + ' of 4 verifiable steps complete';
    }

    get progressValue() {
        return Math.round((this.completedSteps / 4) * 100);
    }

    get userSelectionButtonLabel() {
        return this.showUserSelection ? 'Hide' : 'Assign Users';
    }

    handleAssignAutomation() {
        this.assigningAutomation = true;
        assignAutomationPermSet()
            .then(() => {
                this.showToast('Success', 'Automation permission set assigned to Automated Process user.', 'success');
                return refreshApex(this._wiredStatusResult);
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.assigningAutomation = false;
            });
    }

    handleOpenSiteSetup() {
        window.open('/lightning/setup/Sites/home', '_blank');
    }

    handleOpenNamedCredentials() {
        window.open('/lightning/setup/NamedCredential/home', '_blank');
    }

    handleApiKeyChange(event) {
        this.apiKeyInput = event.target.value;
    }

    handleEditApiKey() {
        this.editingApiKey = true;
    }

    handleCancelApiKey() {
        this.editingApiKey = false;
        this.apiKeyInput = '';
    }

    handleSaveApiKey() {
        this.savingApiKey = true;
        saveApiKey({ apiKey: this.apiKeyInput })
            .then(() => {
                this.showToast('Success', 'API key saved.', 'success');
                this.apiKeyInput = '';
                this.editingApiKey = false;
                return refreshApex(this._wiredStatusResult);
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.savingApiKey = false;
            });
    }

    handleOpenFlows() {
        window.open('/lightning/setup/Flows/home', '_blank');
    }

    handleToggleUserSelection() {
        this.showUserSelection = !this.showUserSelection;
        if (this.showUserSelection && this.availableUsers.length === 0) {
            this.loadAvailableUsers();
        }
    }

    loadAvailableUsers() {
        this.loadingUsers = true;
        getAvailableUsers()
            .then((result) => {
                this.availableUsers = result;
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load users.', 'error');
            })
            .finally(() => {
                this.loadingUsers = false;
            });
    }

    handleUserSelection(event) {
        this.selectedUsers = event.detail.value;
    }

    handleAssignUsers() {
        if (!this.selectedUsers || this.selectedUsers.length === 0) {
            this.showToast('Warning', 'Select at least one user.', 'warning');
            return;
        }
        this.assigningUsers = true;
        var count = this.selectedUsers.length;
        assignUserPermSets({ userIds: this.selectedUsers })
            .then(() => {
                this.showToast('Success', 'Permission set assigned to ' + count + ' user' + (count > 1 ? 's' : '') + '.', 'success');
                this.selectedUsers = [];
                this.loadAvailableUsers();
                return refreshApex(this._wiredStatusResult);
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.assigningUsers = false;
            });
    }

    handleRefresh() {
        this.loading = true;
        refreshApex(this._wiredStatusResult)
            .then(() => {
                if (this.showUserSelection) {
                    this.loadAvailableUsers();
                }
            })
            .finally(() => {
                this.loading = false;
            });
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: title, message: message, variant: variant }));
    }
}
