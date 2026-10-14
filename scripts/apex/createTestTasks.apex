// Phase 5: Live Test Prep Script
// 1. Cleans up existing open tasks for the running user
// 2. Generates test tasks for each grouping: Overdue, Today, Tomorrow, This Week, Next Week, Later

Id currentUserId = UserInfo.getUserId();

// Step 1: Delete existing open tasks assigned to the current user
List<Task> existingTasks = [
    SELECT Id 
    FROM Task 
    WHERE OwnerId = :currentUserId 
      AND IsClosed = false
];

if (!existingTasks.isEmpty()) {
    delete existingTasks;
    System.debug('Deleted ' + existingTasks.size() + ' existing open task(s).');
}

// Step 2: Date boundary calculations (Sunday to Saturday calendar week)
Date today = Date.today();
Date tomorrow = today.addDays(1);

Date knownSunday = Date.newInstance(1900, 1, 7);
Integer dayOfWeek = Math.mod(Math.abs(knownSunday.daysBetween(today)), 7); // 0=Sunday, 6=Saturday
Date endOfThisWeek = today.addDays(6 - dayOfWeek);
Date endOfNextWeek = endOfThisWeek.addDays(7);

List<Task> testTasks = new List<Task>();

// --- Group: Overdue ---
testTasks.add(new Task(
    Subject = 'Follow up with Acme Corp on overdue contract renewal',
    Priority = 'High',
    Status = 'Not Started',
    ActivityDate = today.addDays(-3),
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Submit monthly travel & expense report',
    Priority = 'Normal',
    Status = 'In Progress',
    ActivityDate = today.addDays(-1),
    OwnerId = currentUserId
));

// --- Group: Today ---
testTasks.add(new Task(
    Subject = 'Executive briefing with VP of Global Sales',
    Priority = 'High',
    Status = 'In Progress',
    ActivityDate = today,
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Prepare slide deck for Innovation Day showcase',
    Priority = 'Normal',
    Status = 'Not Started',
    ActivityDate = today,
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Respond to support escalation queue tickets',
    Priority = 'Low',
    Status = 'Not Started',
    ActivityDate = today,
    OwnerId = currentUserId
));

// --- Group: Tomorrow ---
testTasks.add(new Task(
    Subject = 'Review Apex architecture doc & test class patterns',
    Priority = 'High',
    Status = 'Not Started',
    ActivityDate = tomorrow,
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Conduct 1-on-1 sprint planning sync',
    Priority = 'Normal',
    Status = 'Not Started',
    ActivityDate = tomorrow,
    OwnerId = currentUserId
));

// --- Group: This Week ---
if (endOfThisWeek > tomorrow) {
    testTasks.add(new Task(
        Subject = 'Finalize Q4 pipeline forecast and customer milestones',
        Priority = 'High',
        Status = 'Not Started',
        ActivityDate = today.addDays(2),
        OwnerId = currentUserId
    ));
    testTasks.add(new Task(
        Subject = 'Organize internal team feedback survey results',
        Priority = 'Low',
        Status = 'In Progress',
        ActivityDate = endOfThisWeek,
        OwnerId = currentUserId
    ));
}

// --- Group: Next Week ---
testTasks.add(new Task(
    Subject = 'Draft cross-department partner sharing agreement',
    Priority = 'Normal',
    Status = 'Not Started',
    ActivityDate = endOfThisWeek.addDays(2),
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Prepare quarterly security compliance audit evidence',
    Priority = 'High',
    Status = 'Not Started',
    ActivityDate = endOfThisWeek.addDays(4),
    OwnerId = currentUserId
));

// --- Group: Later ---
testTasks.add(new Task(
    Subject = 'Annual vendor contract renegotiation review',
    Priority = 'Normal',
    Status = 'Not Started',
    ActivityDate = endOfNextWeek.addDays(7),
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Evaluate next-generation Lightning Design System tokens',
    Priority = 'Low',
    Status = 'Not Started',
    ActivityDate = endOfNextWeek.addDays(14),
    OwnerId = currentUserId
));
testTasks.add(new Task(
    Subject = 'Explore backlog backlog backlog ideas (no due date set)',
    Priority = 'Normal',
    Status = 'Not Started',
    ActivityDate = null,
    OwnerId = currentUserId
));

// Step 3: Insert test records
insert testTasks;
System.debug('Successfully inserted ' + testTasks.size() + ' test tasks across all groups.');
