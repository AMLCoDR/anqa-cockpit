// ANQA Milestone Database - Integrated from ai-development-monitor
// Based on the database.js from /Volumes/DANIEL/ai-development-monitor

const sqlite3 = require('sqlite3');
const { open } = require('sqlite');
const path = require('path');
const fs = require('fs');

// Create data directory in system-optimization
const DATA_DIR = path.join(__dirname, '../data');
if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
}
const DB_PATH = path.join(DATA_DIR, 'anqa_milestones.db');
let db;

async function initMilestoneDatabase() {
    try {
        db = await open({
            filename: DB_PATH,
            driver: sqlite3.Database
        });

        // Create tables based on ai-development-monitor schema
        await db.exec(`
            CREATE TABLE IF NOT EXISTS milestones (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                is_golden_path BOOLEAN DEFAULT 1,
                phase INTEGER DEFAULT 1,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.exec(`
            CREATE TABLE IF NOT EXISTS todos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                milestone_id INTEGER,
                description TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                priority TEXT DEFAULT 'medium',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (milestone_id) REFERENCES milestones (id)
            )
        `);

        await db.exec(`
            CREATE TABLE IF NOT EXISTS tests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                milestone_id INTEGER,
                name TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                test_type TEXT DEFAULT 'unit',
                last_run DATETIME,
                error_message TEXT,
                FOREIGN KEY (milestone_id) REFERENCES milestones (id)
            )
        `);

        await db.exec(`
            CREATE TABLE IF NOT EXISTS project_activity (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                activity_type TEXT NOT NULL,
                description TEXT NOT NULL,
                metadata TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);

        console.log('🗄️ [INFO] ANQA Milestone database initialized successfully');
        
        // Seed with ANQA project milestones if empty
        await seedANQAMilestones();
        
        return db;
    } catch (error) {
        console.error('❌ [ERROR] Failed to initialize milestone database:', error);
        throw error;
    }
}

async function seedANQAMilestones() {
    const existingMilestones = await db.all('SELECT COUNT(*) as count FROM milestones');
    if (existingMilestones[0].count > 0) {
        console.log('📊 [INFO] Milestone database already contains data');
        return;
    }

    console.log('🌱 [INFO] Seeding ANQA project milestones...');
    
    const anqaMilestones = [
        {
            name: "Cockpit System Development",
            phase: 1,
            todos: [
                "Real-time system monitoring dashboard",
                "Two-way chat integration",
                "File oversight system",
                "Command execution interface"
            ],
            tests: [
                "Cockpit API endpoints test",
                "WebSocket communication test",
                "File monitoring test"
            ]
        },
        {
            name: "Database Integration & Schema",
            phase: 2,
            todos: [
                "PostgreSQL database setup",
                "Schema migration scripts",
                "Data integrity validation",
                "Backup and recovery procedures"
            ],
            tests: [
                "Database connection test",
                "Schema validation test",
                "Data migration test"
            ]
        },
        {
            name: "Frontend Development",
            phase: 3,
            todos: [
                "React components optimization",
                "Responsive design implementation",
                "Performance optimization",
                "User interface enhancements"
            ],
            tests: [
                "Component rendering test",
                "UI interaction test",
                "Performance benchmarks"
            ]
        },
        {
            name: "Backend API Enhancement",
            phase: 4,
            todos: [
                "API endpoint optimization",
                "Authentication improvements",
                "Error handling enhancement",
                "Rate limiting implementation"
            ],
            tests: [
                "API endpoint tests",
                "Authentication flow test",
                "Error handling test"
            ]
        },
        {
            name: "System Integration & Testing",
            phase: 5,
            todos: [
                "End-to-end testing",
                "Performance optimization",
                "Security audit",
                "Documentation completion"
            ],
            tests: [
                "Integration test suite",
                "Performance tests",
                "Security vulnerability scan"
            ]
        }
    ];

    for (const milestone of anqaMilestones) {
        const milestoneId = await addMilestone(milestone.name, true, milestone.phase);
        
        // Add todos
        for (const todoDesc of milestone.todos) {
            await addTodo(milestoneId, todoDesc);
        }
        
        // Add tests
        for (const testName of milestone.tests) {
            await addTest(milestoneId, testName);
        }
    }
    
    console.log('✅ [INFO] ANQA project milestones seeded successfully');
}

async function addMilestone(name, isGoldenPath = true, phase = 1) {
    const result = await db.run(
        'INSERT INTO milestones (name, is_golden_path, phase) VALUES (?, ?, ?)', 
        [name, isGoldenPath, phase]
    );
    
    await logActivity('milestone_created', `Created milestone: ${name}`, { 
        milestoneId: result.lastID, 
        phase: phase 
    });
    
    return result.lastID;
}

async function updateMilestoneStatus(id, status) {
    await db.run(
        'UPDATE milestones SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', 
        [status, id]
    );
    
    const milestone = await db.get('SELECT name FROM milestones WHERE id = ?', [id]);
    await logActivity('milestone_updated', `Milestone "${milestone.name}" status changed to ${status}`, { 
        milestoneId: id, 
        status: status 
    });
}

async function addTodo(milestone_id, description, priority = 'medium') {
    const result = await db.run(
        'INSERT INTO todos (milestone_id, description, priority) VALUES (?, ?, ?)', 
        [milestone_id, description, priority]
    );
    
    await logActivity('todo_created', `Created todo: ${description}`, { 
        todoId: result.lastID, 
        milestoneId: milestone_id 
    });
    
    return result.lastID;
}

async function updateTodoStatus(id, status) {
    await db.run(
        'UPDATE todos SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', 
        [status, id]
    );
    
    const todo = await db.get('SELECT description FROM todos WHERE id = ?', [id]);
    await logActivity('todo_updated', `Todo "${todo.description}" marked as ${status}`, { 
        todoId: id, 
        status: status 
    });
    
    // Check if this completes a milestone
    await checkMilestoneCompletion(id);
}

async function addTest(milestone_id, name, testType = 'unit') {
    const result = await db.run(
        'INSERT INTO tests (milestone_id, name, test_type) VALUES (?, ?, ?)', 
        [milestone_id, name, testType]
    );
    
    await logActivity('test_created', `Created test: ${name}`, { 
        testId: result.lastID, 
        milestoneId: milestone_id 
    });
    
    return result.lastID;
}

async function updateTestStatus(id, status, errorMessage = null) {
    await db.run(
        'UPDATE tests SET status = ?, last_run = CURRENT_TIMESTAMP, error_message = ? WHERE id = ?', 
        [status, errorMessage, id]
    );
    
    const test = await db.get('SELECT name, milestone_id FROM tests WHERE id = ?', [id]);
    
    // Regression detection - check if a passing test failed
    if (status === 'failed') {
        const wasPassingBefore = await db.get(
            'SELECT * FROM project_activity WHERE activity_type = "test_updated" AND metadata LIKE ? ORDER BY timestamp DESC LIMIT 1',
            [`%"testId":${id}%"status":"passed"%`]
        );
        
        if (wasPassingBefore) {
            await logActivity('regression_detected', `🚨 REGRESSION: Test "${test.name}" was passing but now failed!`, { 
                testId: id, 
                milestoneId: test.milestone_id,
                errorMessage: errorMessage,
                isRegression: true
            });
        }
    }
    
    await logActivity('test_updated', `Test "${test.name}" ${status}`, { 
        testId: id, 
        status: status,
        errorMessage: errorMessage
    });
}

async function checkMilestoneCompletion(todoId) {
    // Get milestone ID from todo
    const todo = await db.get('SELECT milestone_id FROM todos WHERE id = ?', [todoId]);
    if (!todo) return;
    
    // Check if all todos in milestone are completed
    const incompleteTodos = await db.get(
        'SELECT COUNT(*) as count FROM todos WHERE milestone_id = ? AND status != "completed"',
        [todo.milestone_id]
    );
    
    if (incompleteTodos.count === 0) {
        await updateMilestoneStatus(todo.milestone_id, 'completed');
    }
}

async function logActivity(activityType, description, metadata = {}) {
    await db.run(
        'INSERT INTO project_activity (activity_type, description, metadata) VALUES (?, ?, ?)',
        [activityType, description, JSON.stringify(metadata)]
    );
}

async function getProjectState() {
    if (!db) await initMilestoneDatabase();
    
    const milestones = await db.all(`
        SELECT m.*, 
               COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_todos,
               COUNT(t.id) as total_todos,
               COUNT(CASE WHEN tests.status = 'passed' THEN 1 END) as passed_tests,
               COUNT(tests.id) as total_tests
        FROM milestones m
        LEFT JOIN todos t ON m.id = t.milestone_id
        LEFT JOIN tests ON m.id = tests.milestone_id
        GROUP BY m.id
        ORDER BY m.phase, m.id
    `);
    
    const todos = await db.all('SELECT * FROM todos ORDER BY milestone_id, id');
    const tests = await db.all('SELECT * FROM tests ORDER BY milestone_id, id');
    const recentActivity = await db.all(
        'SELECT * FROM project_activity ORDER BY timestamp DESC LIMIT 20'
    );
    
    return { milestones, todos, tests, recentActivity };
}

async function getRecentRegressions() {
    return await db.all(`
        SELECT * FROM project_activity 
        WHERE activity_type = 'regression_detected' 
        ORDER BY timestamp DESC 
        LIMIT 10
    `);
}

async function getProjectMetrics() {
    const metrics = await db.get(`
        SELECT 
            COUNT(DISTINCT m.id) as total_milestones,
            COUNT(DISTINCT CASE WHEN m.status = 'completed' THEN m.id END) as completed_milestones,
            COUNT(DISTINCT t.id) as total_todos,
            COUNT(DISTINCT CASE WHEN t.status = 'completed' THEN t.id END) as completed_todos,
            COUNT(DISTINCT tests.id) as total_tests,
            COUNT(DISTINCT CASE WHEN tests.status = 'passed' THEN tests.id END) as passed_tests,
            COUNT(DISTINCT CASE WHEN tests.status = 'failed' THEN tests.id END) as failed_tests
        FROM milestones m
        LEFT JOIN todos t ON m.id = t.milestone_id
        LEFT JOIN tests ON m.id = tests.milestone_id
    `);
    
    return metrics;
}

// Command processing (integrated from ai-development-monitor)
async function processCommand(commandString) {
    const [command, ...args] = commandString.split(':');
    const value = args.join(':').trim();
    let stateChanged = false;
    
    console.log(`🔧 [COMMAND] Processing: ${command} -> ${value}`);
    
    try {
        switch (command.trim().toLowerCase()) {
            case 'complete_task':
            case 'complete_todo':
                const todo = await db.get('SELECT id FROM todos WHERE description LIKE ?', [`%${value}%`]);
                if (todo) {
                    await updateTodoStatus(todo.id, 'completed');
                    console.log(`✅ [ACTION] Marked todo as complete: "${value}"`);
                    stateChanged = true;
                } else {
                    console.log(`⚠️ [WARNING] Todo not found: "${value}"`);
                }
                break;
                
            case 'fail_test':
                const test = await db.get('SELECT id FROM tests WHERE name LIKE ?', [`%${value}%`]);
                if (test) {
                    await updateTestStatus(test.id, 'failed', 'Test failed via command');
                    console.log(`❌ [ACTION] Marked test as failed: "${value}"`);
                    stateChanged = true;
                } else {
                    console.log(`⚠️ [WARNING] Test not found: "${value}"`);
                }
                break;
                
            case 'pass_test':
                const passingTest = await db.get('SELECT id FROM tests WHERE name LIKE ?', [`%${value}%`]);
                if (passingTest) {
                    await updateTestStatus(passingTest.id, 'passed');
                    console.log(`✅ [ACTION] Marked test as passed: "${value}"`);
                    stateChanged = true;
                } else {
                    console.log(`⚠️ [WARNING] Test not found: "${value}"`);
                }
                break;
                
            case 'start_milestone':
                const milestone = await db.get('SELECT id FROM milestones WHERE name LIKE ?', [`%${value}%`]);
                if (milestone) {
                    await updateMilestoneStatus(milestone.id, 'in_progress');
                    console.log(`🚀 [ACTION] Started milestone: "${value}"`);
                    stateChanged = true;
                } else {
                    console.log(`⚠️ [WARNING] Milestone not found: "${value}"`);
                }
                break;
                
            default:
                console.log(`❓ [WARNING] Unknown command: "${command}"`);
        }
    } catch (error) {
        console.error(`❌ [ERROR] Command processing failed:`, error);
    }
    
    return stateChanged;
}

module.exports = {
    initMilestoneDatabase,
    addMilestone,
    updateMilestoneStatus,
    addTodo,
    updateTodoStatus,
    addTest,
    updateTestStatus,
    getProjectState,
    getRecentRegressions,
    getProjectMetrics,
    processCommand,
    logActivity,
    DATA_DIR
};
