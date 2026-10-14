public with sharing class TaskManagerApexController {
    
    /**
     * Retrieves all open tasks assigned to the current running user,
     * grouped by: Overdue, Today, Tomorrow, This Week, Next Week, Later.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Task>> getTasks() {
        Map<String, List<Task>> groupedTasks = new Map<String, List<Task>>{
            'Overdue' => new List<Task>(),
            'Today' => new List<Task>(),
            'Tomorrow' => new List<Task>(),
            'This Week' => new List<Task>(),
            'Next Week' => new List<Task>(),
            'Later' => new List<Task>()
        };

        Id currentUserId = UserInfo.getUserId();
        List<Task> openTasks = [
            SELECT Id, Subject, Priority, Status, ActivityDate, OwnerId, IsClosed
            FROM Task
            WHERE OwnerId = :currentUserId
              AND IsClosed = false
            ORDER BY ActivityDate ASC NULLS LAST, CreatedDate DESC
        ];

        Date today = Date.today();
        Date tomorrow = today.addDays(1);

        // Calculate end of this week (Saturday) and next week (following Saturday)
        // using Sunday-to-Saturday calendar week
        Date knownSunday = Date.newInstance(1900, 1, 7);
        Integer dayOfWeek = Math.mod(Math.abs(knownSunday.daysBetween(today)), 7); // 0=Sunday, 6=Saturday
        Date endOfThisWeek = today.addDays(6 - dayOfWeek);
        Date endOfNextWeek = endOfThisWeek.addDays(7);

        for (Task t : openTasks) {
            Date dueDate = t.ActivityDate;

            if (dueDate == null) {
                groupedTasks.get('Later').add(t);
            } else if (dueDate < today) {
                groupedTasks.get('Overdue').add(t);
            } else if (dueDate == today) {
                groupedTasks.get('Today').add(t);
            } else if (dueDate == tomorrow) {
                groupedTasks.get('Tomorrow').add(t);
            } else if (dueDate <= endOfThisWeek) {
                groupedTasks.get('This Week').add(t);
            } else if (dueDate <= endOfNextWeek) {
                groupedTasks.get('Next Week').add(t);
            } else {
                groupedTasks.get('Later').add(t);
            }
        }

        return groupedTasks;
    }

    /**
     * Marks a task status as Completed.
     * Returns true on success, false on failure.
     */
    @AuraEnabled
    public static Boolean closeTask(Id taskId) {
        try {
            if (taskId == null) {
                return false;
            }
            Task taskRecord = [SELECT Id, Status FROM Task WHERE Id = :taskId LIMIT 1];
            taskRecord.Status = 'Completed';
            update taskRecord;
            return true;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error completing task ' + taskId + ': ' + ex.getMessage());
            return false;
        }
    }

    /**
     * Defers a task due date to tomorrow (or next business day if Friday/Saturday).
     * Returns true on success, false on failure.
     */
    @AuraEnabled
    public static Boolean deferTask(Id taskId) {
        try {
            if (taskId == null) {
                return false;
            }
            Task taskRecord = [SELECT Id, ActivityDate FROM Task WHERE Id = :taskId LIMIT 1];

            Date today = Date.today();
            Date knownSunday = Date.newInstance(1900, 1, 7);
            Integer dayOfWeek = Math.mod(Math.abs(knownSunday.daysBetween(today)), 7);

            Date targetDate;
            if (dayOfWeek == 5) {
                // Friday -> Defer to Monday (next business day)
                targetDate = today.addDays(3);
            } else if (dayOfWeek == 6) {
                // Saturday -> Defer to Monday (next business day)
                targetDate = today.addDays(2);
            } else {
                targetDate = today.addDays(1);
            }

            taskRecord.ActivityDate = targetDate;
            update taskRecord;
            return true;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error deferring task ' + taskId + ': ' + ex.getMessage());
            return false;
        }
    }
}
