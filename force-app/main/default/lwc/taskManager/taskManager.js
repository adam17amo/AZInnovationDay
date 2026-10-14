import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getTasks from '@salesforce/apex/TaskManagerApexController.getTasks';
import closeTask from '@salesforce/apex/TaskManagerApexController.closeTask';
import deferTask from '@salesforce/apex/TaskManagerApexController.deferTask';

const SECTION_ORDER = ['Overdue', 'Today', 'Tomorrow', 'This Week', 'Next Week', 'Later'];

const PRIORITY_ORDER = {
    'High': 1,
    'Normal': 2,
    'Low': 3
};

export default class TaskManager extends NavigationMixin(LightningElement) {
    @track groupedTasks = {
        'Overdue': [],
        'Today': [],
        'Tomorrow': [],
        'This Week': [],
        'Next Week': [],
        'Later': []
    };

    @track activeSections = ['Overdue', 'Today', 'Tomorrow', 'This Week'];
    isLoading = true;
    error = null;
    wiredTasksResult;

    @wire(getTasks)
    wiredGetTasks(result) {
        this.wiredTasksResult = result;
        const { data, error } = result;
        this.isLoading = false;

        if (data) {
            const freshMap = {};
            SECTION_ORDER.forEach((key) => {
                freshMap[key] = data[key] ? [...data[key]] : [];
            });
            this.groupedTasks = freshMap;
            this.error = null;
        } else if (error) {
            this.error = error;
            console.error('Error fetching tasks from Apex:', error);
        }
    }

    get sections() {
        return SECTION_ORDER.map((sectionName) => {
            const rawTasks = this.groupedTasks[sectionName] || [];

            // Sort High -> Normal -> Low
            const sortedTasks = [...rawTasks].sort((a, b) => {
                const rankA = PRIORITY_ORDER[a.Priority] || 99;
                const rankB = PRIORITY_ORDER[b.Priority] || 99;
                return rankA - rankB;
            }).map((task) => ({
                ...task,
                priorityBadgeClass: this.getPriorityBadgeClass(task.Priority)
            }));

            return {
                name: sectionName,
                label: `${sectionName} (${sortedTasks.length})`,
                tasks: sortedTasks,
                hasTasks: sortedTasks.length > 0
            };
        });
    }

    get totalOpenTasksLabel() {
        let count = 0;
        SECTION_ORDER.forEach((key) => {
            count += (this.groupedTasks[key] || []).length;
        });
        return `${count} Open ${count === 1 ? 'Task' : 'Tasks'}`;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        }
        return JSON.stringify(this.error);
    }

    getPriorityBadgeClass(priority) {
        switch (priority) {
            case 'High':
                return 'slds-badge slds-theme_error';
            case 'Normal':
                return 'slds-badge slds-badge_lightest';
            case 'Low':
                return 'slds-badge slds-theme_shade';
            default:
                return 'slds-badge';
        }
    }

    handleSectionToggle(event) {
        this.activeSections = event.detail.openSections;
    }

    handleSubjectClick(event) {
        const taskId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                objectApiName: 'Task',
                actionName: 'view'
            }
        });
    }

    async handleCompleteTask(event) {
        const taskId = event.target.name || event.currentTarget.dataset?.id || event.target.dataset?.id;
        if (!taskId) return;

        // Snapshot current state for rollback if server call fails
        const previousState = JSON.parse(JSON.stringify(this.groupedTasks));
        let taskSubject = '';

        // Optimistic UI update: remove task immediately
        SECTION_ORDER.forEach((section) => {
            const index = (this.groupedTasks[section] || []).findIndex((t) => t.Id === taskId);
            if (index !== -1) {
                taskSubject = this.groupedTasks[section][index].Subject;
                this.groupedTasks[section] = this.groupedTasks[section].filter((t) => t.Id !== taskId);
            }
        });
        this.groupedTasks = { ...this.groupedTasks };

        try {
            const isSuccess = await closeTask({ taskId });
            if (isSuccess) {
                this.showToast('Task Completed', `"${taskSubject}" marked as completed.`, 'success');
                await refreshApex(this.wiredTasksResult);
            } else {
                // Rollback UI
                this.groupedTasks = previousState;
                this.showToast('Error', 'Unable to complete the task. Please try again.', 'error');
            }
        } catch (err) {
            // Rollback UI
            this.groupedTasks = previousState;
            this.showToast('Error', err?.body?.message || 'Failed to complete task.', 'error');
        }
    }

    async handleDeferTask(event) {
        const taskId = event.target.name || event.currentTarget.dataset?.id || event.target.dataset?.id;
        if (!taskId) return;

        // Snapshot current state for rollback if server call fails
        const previousState = JSON.parse(JSON.stringify(this.groupedTasks));
        let foundTask = null;

        // Find and remove task from its current section
        SECTION_ORDER.forEach((section) => {
            const tasks = this.groupedTasks[section] || [];
            const index = tasks.findIndex((t) => t.Id === taskId);
            if (index !== -1) {
                foundTask = { ...tasks[index] };
                this.groupedTasks[section] = tasks.filter((t) => t.Id !== taskId);
            }
        });

        if (foundTask) {
            // Update activity date representation for UI
            const tomorrowDate = this.calculateNextBusinessDate();
            foundTask.ActivityDate = tomorrowDate;

            // Add to Tomorrow with new immutable array reference
            this.groupedTasks['Tomorrow'] = [...(this.groupedTasks['Tomorrow'] || []), foundTask];
            this.groupedTasks = { ...this.groupedTasks };

            // Ensure "Tomorrow" accordion is expanded so user sees the task arrive
            if (!this.activeSections.includes('Tomorrow')) {
                this.activeSections = [...this.activeSections, 'Tomorrow'];
            }

            try {
                const isSuccess = await deferTask({ taskId });
                if (isSuccess) {
                    this.showToast('Task Deferred', `"${foundTask.Subject}" moved to Tomorrow.`, 'success');
                    await refreshApex(this.wiredTasksResult);
                } else {
                    // Rollback UI
                    this.groupedTasks = previousState;
                    this.showToast('Error', 'Unable to defer task. Please try again.', 'error');
                }
            } catch (err) {
                // Rollback UI
                this.groupedTasks = previousState;
                this.showToast('Error', err?.body?.message || 'Failed to defer task.', 'error');
            }
        }
    }

    calculateNextBusinessDate() {
        const d = new Date();
        const dayOfWeek = d.getDay(); // 0=Sunday, 5=Friday, 6=Saturday
        let addDays = 1;
        if (dayOfWeek === 5) {
            addDays = 3; // Friday -> Monday
        } else if (dayOfWeek === 6) {
            addDays = 2; // Saturday -> Monday
        }
        d.setDate(d.getDate() + addDays);

        // Format local date YYYY-MM-DD without UTC timezone offset issues
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredTasksResult)
            .catch((err) => {
                this.showToast('Error', 'Error refreshing tasks: ' + (err?.body?.message || err), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
