@isTest
private class TaskManagerApexControllerTest {

    @testSetup
    static void setupTestData() {
        Date today = Date.today();
        Date knownSunday = Date.newInstance(1900, 1, 7);
        Integer dayOfWeek = Math.mod(Math.abs(knownSunday.daysBetween(today)), 7);
        Date endOfThisWeek = today.addDays(6 - dayOfWeek);
        Date endOfNextWeek = endOfThisWeek.addDays(7);

        Id currentUserId = UserInfo.getUserId();

        List<Task> testTasks = new List<Task>{
            new Task(Subject = 'Overdue Task', Priority = 'High', Status = 'Not Started', ActivityDate = today.addDays(-2), OwnerId = currentUserId),
            new Task(Subject = 'Today Task', Priority = 'Normal', Status = 'In Progress', ActivityDate = today, OwnerId = currentUserId),
            new Task(Subject = 'Tomorrow Task', Priority = 'High', Status = 'Not Started', ActivityDate = today.addDays(1), OwnerId = currentUserId),
            new Task(Subject = 'Next Week Task', Priority = 'Normal', Status = 'Not Started', ActivityDate = endOfThisWeek.addDays(2), OwnerId = currentUserId),
            new Task(Subject = 'Later Task Future', Priority = 'Low', Status = 'Not Started', ActivityDate = endOfNextWeek.addDays(3), OwnerId = currentUserId),
            new Task(Subject = 'Later Task No Due Date', Priority = 'Normal', Status = 'Not Started', ActivityDate = null, OwnerId = currentUserId)
        };

        // Add a This Week task if there are remaining days in this week after tomorrow
        if (endOfThisWeek > today.addDays(1)) {
            testTasks.add(new Task(
                Subject = 'This Week Task',
                Priority = 'High',
                Status = 'Not Started',
                ActivityDate = today.addDays(2),
                OwnerId = currentUserId
            ));
        }

        // Add a task that is completed (should be excluded by getTasks)
        testTasks.add(new Task(
            Subject = 'Completed Task',
            Priority = 'Normal',
            Status = 'Completed',
            ActivityDate = today,
            OwnerId = currentUserId
        ));

        insert testTasks;
    }

    @isTest
    static void testGetTasks() {
        Test.startTest();
        Map<String, List<Task>> result = TaskManagerApexController.getTasks();
        Test.stopTest();

        Assert.isNotNull(result, 'Result map should not be null');
        Assert.isTrue(result.containsKey('Overdue'), 'Should contain Overdue key');
        Assert.isTrue(result.containsKey('Today'), 'Should contain Today key');
        Assert.isTrue(result.containsKey('Tomorrow'), 'Should contain Tomorrow key');
        Assert.isTrue(result.containsKey('This Week'), 'Should contain This Week key');
        Assert.isTrue(result.containsKey('Next Week'), 'Should contain Next Week key');
        Assert.isTrue(result.containsKey('Later'), 'Should contain Later key');

        Assert.areEqual(1, result.get('Overdue').size(), 'Should have 1 Overdue task');
        Assert.areEqual('Overdue Task', result.get('Overdue')[0].Subject);

        Assert.areEqual(1, result.get('Today').size(), 'Should have 1 Today task (closed task should be excluded)');
        Assert.areEqual('Today Task', result.get('Today')[0].Subject);

        Assert.areEqual(1, result.get('Tomorrow').size(), 'Should have 1 Tomorrow task');
        Assert.areEqual('Tomorrow Task', result.get('Tomorrow')[0].Subject);

        Assert.areEqual(1, result.get('Next Week').size(), 'Should have 1 Next Week task');
        Assert.areEqual(2, result.get('Later').size(), 'Should have 2 Later tasks (one future, one null due date)');
    }

    @isTest
    static void testCloseTaskSuccess() {
        Task t = [SELECT Id, Status FROM Task WHERE Subject = 'Today Task' LIMIT 1];
        Assert.areEqual('In Progress', t.Status, 'Initial status should be In Progress');

        Test.startTest();
        Boolean success = TaskManagerApexController.closeTask(t.Id);
        Test.stopTest();

        Assert.isTrue(success, 'closeTask should return true');

        Task updatedTask = [SELECT Id, Status, IsClosed FROM Task WHERE Id = :t.Id];
        Assert.areEqual('Completed', updatedTask.Status, 'Task status should be Completed');
        Assert.isTrue(updatedTask.IsClosed, 'Task should be closed');
    }

    @isTest
    static void testCloseTaskFailure() {
        Test.startTest();
        Boolean nullResult = TaskManagerApexController.closeTask(null);
        Id fakeTaskId = '00T000000000001AAA';
        Boolean invalidIdResult = TaskManagerApexController.closeTask(fakeTaskId);
        Test.stopTest();

        Assert.isFalse(nullResult, 'closeTask with null ID should return false');
        Assert.isFalse(invalidIdResult, 'closeTask with nonexistent ID should return false');
    }

    @isTest
    static void testDeferTaskSuccess() {
        Task t = [SELECT Id, ActivityDate FROM Task WHERE Subject = 'Today Task' LIMIT 1];

        Test.startTest();
        Boolean success = TaskManagerApexController.deferTask(t.Id);
        Test.stopTest();

        Assert.isTrue(success, 'deferTask should return true');

        Task updatedTask = [SELECT Id, ActivityDate FROM Task WHERE Id = :t.Id];
        Date today = Date.today();
        Date knownSunday = Date.newInstance(1900, 1, 7);
        Integer dayOfWeek = Math.mod(Math.abs(knownSunday.daysBetween(today)), 7);

        Date expectedDate;
        if (dayOfWeek == 5) {
            expectedDate = today.addDays(3);
        } else if (dayOfWeek == 6) {
            expectedDate = today.addDays(2);
        } else {
            expectedDate = today.addDays(1);
        }

        Assert.areEqual(expectedDate, updatedTask.ActivityDate, 'Task due date should be deferred to expected date');
    }

    @isTest
    static void testDeferTaskFailure() {
        Test.startTest();
        Boolean nullResult = TaskManagerApexController.deferTask(null);
        Id fakeTaskId = '00T000000000001AAA';
        Boolean invalidIdResult = TaskManagerApexController.deferTask(fakeTaskId);
        Test.stopTest();

        Assert.isFalse(nullResult, 'deferTask with null ID should return false');
        Assert.isFalse(invalidIdResult, 'deferTask with nonexistent ID should return false');
    }
}
