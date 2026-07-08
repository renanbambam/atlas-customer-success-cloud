import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { publish, subscribe, MessageContext } from 'lightning/messageService';
import HEALTH_REFRESH_CHANNEL from '@salesforce/messageChannel/HealthScoreRefresh__c';
import getHealthSummary from '@salesforce/apex/HealthScoreController.getHealthSummary';
import recalculate from '@salesforce/apex/HealthScoreController.recalculate';

const SPARKLINE_WIDTH = 260;
const SPARKLINE_HEIGHT = 48;

const RISK_BADGE_CLASSES = {
    Low: 'slds-badge slds-theme_success',
    Medium: 'slds-badge slds-theme_warning',
    High: 'slds-badge slds-theme_error'
};

export default class HealthScorePanel extends LightningElement {
    @api recordId;

    isRecalculating = false;
    subscription = null;
    wiredSummary;

    @wire(MessageContext)
    messageContext;

    @wire(getHealthSummary, { accountId: '$recordId' })
    handleSummary(result) {
        this.wiredSummary = result;
    }

    connectedCallback() {
        // Another component (or a future one) may trigger a recalculation;
        // this panel refreshes itself instead of waiting for a page reload.
        this.subscription = subscribe(this.messageContext, HEALTH_REFRESH_CHANNEL, (message) => {
            if (message.accountId === this.recordId) {
                refreshApex(this.wiredSummary);
            }
        });
    }

    get summary() {
        return this.wiredSummary && this.wiredSummary.data;
    }

    get isLoading() {
        return !this.wiredSummary || (!this.wiredSummary.data && !this.wiredSummary.error);
    }

    get errorMessage() {
        const error = this.wiredSummary && this.wiredSummary.error;
        if (!error) {
            return null;
        }
        return (error.body && error.body.message) || 'Unable to load the health score.';
    }

    get hasScore() {
        return this.summary && this.summary.score !== null && this.summary.score !== undefined;
    }

    get riskBadgeClass() {
        return RISK_BADGE_CLASSES[this.summary && this.summary.churnRisk] || 'slds-badge';
    }

    get dimensions() {
        if (!this.summary) {
            return [];
        }
        return [
            { label: 'Adoption', value: this.summary.adoptionScore },
            { label: 'Support', value: this.summary.supportScore },
            { label: 'Engagement', value: this.summary.engagementScore },
            { label: 'Financial', value: this.summary.financialScore }
        ]
            .filter((dimension) => dimension.value !== null && dimension.value !== undefined)
            .map((dimension) => ({
                ...dimension,
                barStyle: `width: ${dimension.value}%`
            }));
    }

    get hasHistory() {
        return this.summary && this.summary.history && this.summary.history.length > 1;
    }

    get sparklinePoints() {
        if (!this.hasHistory) {
            return '';
        }
        const history = this.summary.history;
        const stepX = SPARKLINE_WIDTH / (history.length - 1);
        return history
            .map((point, index) => {
                const x = (index * stepX).toFixed(1);
                const y = (SPARKLINE_HEIGHT - (point.score / 100) * SPARKLINE_HEIGHT).toFixed(1);
                return `${x},${y}`;
            })
            .join(' ');
    }

    get viewBox() {
        return `0 0 ${SPARKLINE_WIDTH} ${SPARKLINE_HEIGHT}`;
    }

    async handleRecalculate() {
        this.isRecalculating = true;
        try {
            await recalculate({ accountId: this.recordId });
            await refreshApex(this.wiredSummary);
            publish(this.messageContext, HEALTH_REFRESH_CHANNEL, { accountId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Health score updated',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Recalculation failed',
                    message: (error.body && error.body.message) || 'Unexpected error',
                    variant: 'error'
                })
            );
        } finally {
            this.isRecalculating = false;
        }
    }
}
