from app.celery_app import celery_app
import time
import random
from celery import group, chain, chord

@celery_app.task
def add(x, y):
    """
    Basic arithmetic task that adds two numbers.
    
    This task serves as a fundamental building block for demonstrating Celery's
    core functionality. The 20-second sleep simulates real-world scenarios
    where tasks perform time-consuming operations like database queries,
    API calls, or file processing.
    
    Args:
        x (int/float): First number to add
        y (int/float): Second number to add
    
    Returns:
        int/float: Sum of x and y
        
    Use cases:
        - Testing basic task queuing and execution
        - Monitoring task progress and completion
        - Building blocks for complex workflows (chains, chords, groups)
        - Load testing with predictable execution time
    """
    time.sleep(20)  # Simulate a long-running task (e.g., database operation)
    return x + y

@celery_app.task(bind=True, max_retries=3, default_retry_delay=5)
def failing_task(self):
    """
    Demonstrates Celery's automatic retry mechanism with configurable behavior.
    
    This task randomly fails to simulate unreliable external dependencies
    (network issues, temporary service unavailability, etc.). The retry
    mechanism is essential for building resilient distributed systems.
    
    Task Configuration:
        - bind=True: Provides access to task instance (self) for retry control
        - max_retries=3: Maximum number of retry attempts before giving up
        - default_retry_delay=5: Wait 5 seconds between retry attempts
    
    Returns:
        str: Success message if task eventually succeeds
        
    Raises:
        ValueError: Random failure to trigger retry mechanism
        
    Retry Strategy:
        1. Task executes with 50% chance of failure
        2. On failure, Celery automatically schedules retry after 5 seconds
        3. Process repeats up to 3 times before final failure
        4. Exponential backoff can be implemented for more sophisticated strategies
    """
    if random.choice([True, False]):
        # Simulate random failure (network timeout, service unavailable, etc.)
        raise self.retry(exc=ValueError("Random failure"))
    return "Succeeded"

@celery_app.task
def scheduled_task():
    """
    Example task designed for periodic execution via Celery Beat scheduler.
    
    Celery Beat is a scheduler that runs tasks at regular intervals or specific
    times (cron-like functionality). This task demonstrates how to create
    functions that are triggered by time rather than application events.
    
    Common scheduling patterns:
        - Every few seconds/minutes/hours
        - Daily at specific time (e.g., midnight reports)
        - Weekly/monthly maintenance tasks
        - Cron-style expressions for complex schedules
    
    Configuration in celery_app.py:
        beat_schedule = {
            'run-every-30-seconds': {
                'task': 'app.tasks.scheduled_task',
                'schedule': 30.0,
            }
        }
    
    Returns:
        str: Confirmation message with timestamp information
        
    Use cases:
        - Generating daily/weekly reports
        - Cleaning up temporary files
        - Sending periodic notifications
        - Health checks and monitoring
        - Data synchronization between systems
    """
    print("This task runs on a schedule.")
    return "Scheduled task executed by Celery Beat"

@celery_app.task
def important_task():
    """
    High-priority task demonstrating queue routing and priority handling.
    
    In production systems, different tasks have different urgency levels.
    This task represents critical operations that should be processed
    immediately, bypassing normal queue ordering.
    
    Queue Routing Configuration:
        - Route to dedicated 'priority' queue
        - Assign dedicated workers to priority queue
        - Configure separate worker processes for high-priority tasks
        
    Example routing in celery_app.py:
        task_routes = {
            'app.tasks.important_task': {'queue': 'priority'},
        }
    
    Worker Configuration:
        # Start priority worker: celery -A app.celery_app worker -Q priority
        # Start normal worker: celery -A app.celery_app worker -Q default
    
    Returns:
        str: Confirmation of high-priority task execution
        
    Use cases:
        - Payment processing
        - Security alerts
        - System health checks
        - User authentication tasks
        - Critical data updates
    """
    print("This is an important task.")
    return "Important task executed"

@celery_app.task
def long_running_task():
    """
    Simulates tasks with extended execution times for timeout and monitoring testing.
    
    Long-running tasks present unique challenges in distributed systems:
    - Worker timeout configuration
    - Progress monitoring and reporting
    - Graceful cancellation
    - Resource management
    - Client timeout handling
    
    Configuration Considerations:
        - Set appropriate worker timeouts (longer than task duration)
        - Implement progress reporting for user feedback
        - Consider task chunking for very long operations
        - Monitor memory usage during execution
        
    Timeout Settings:
        CELERYD_TASK_TIME_LIMIT = 60 * 30  # 30 minutes hard limit
        CELERYD_TASK_SOFT_TIME_LIMIT = 60 * 25  # 25 minutes soft limit
    
    Returns:
        str: Completion confirmation after 30 seconds
        
    Use cases:
        - Large file processing
        - Data migration tasks
        - Machine learning model training
        - Bulk data analysis
        - Video/image processing
        - Report generation with large datasets
    """
    time.sleep(30)  # Simulate long computation (e.g., data processing)
    return "Long-running task completed"

@celery_app.task
def cpu_burn(n: int = 5_000_00):
    """
    CPU-intensive task for performance testing and worker optimization.
    
    This task creates a computational workload to test CPU-bound task
    performance. Unlike I/O bound tasks, CPU-intensive tasks benefit
    from different worker configurations and concurrency models.
    
    Performance Considerations:
        - CPU-bound tasks should use process-based workers (default)
        - Worker concurrency should match CPU core count
        - Consider using separate workers for CPU vs I/O tasks
        - Monitor CPU utilization and worker memory usage
        
    Worker Configuration for CPU tasks:
        # Use processes (not threads) for CPU-bound work
        celery -A app.celery_app worker --concurrency=4 --pool=prefork
    
    Args:
        n (int): Number of iterations (default: 500,000)
                Larger values increase CPU load and execution time
    
    Returns:
        int: Sum of all numbers from 0 to n-1
        
    Use cases:
        - Mathematical computations
        - Data analysis algorithms
        - Image/video processing
        - Cryptographic operations
        - Performance benchmarking
        - Load testing worker capacity
    """
    s = 0
    # Intensive loop simulating complex calculations
    for i in range(n):
        s += i  # Simple arithmetic to consume CPU cycles
    return s

@celery_app.task
def io_bound_task(ms: int = 200):
    """
    I/O bound task simulation for testing concurrency and async performance.
    
    I/O bound tasks spend most of their time waiting for external resources
    rather than consuming CPU. These tasks benefit from different optimization
    strategies compared to CPU-bound tasks.
    
    Optimization Strategies:
        - Use thread-based workers for better concurrency
        - Higher worker concurrency settings
        - Async/await patterns where applicable
        - Connection pooling for database/API calls
        
    Worker Configuration for I/O tasks:
        # Use threads for I/O-bound work
        celery -A app.celery_app worker --pool=threads --concurrency=100
        
    Alternative pools:
        - eventlet: For async I/O operations
        - gevent: For greenlet-based concurrency
    
    Args:
        ms (int): Milliseconds to sleep (default: 200ms)
                 Simulates waiting for external resource response time
    
    Returns:
        str: Completion message with timing information
        
    Use cases:
        - Database queries
        - HTTP API calls
        - File system operations
        - Network operations
        - Email sending
        - External service integrations
    """
    time.sleep(ms / 1000)  # Convert milliseconds to seconds
    return f"IO bound task completed after {ms} ms"

@celery_app.task
def multiply(x: int, y: int):
    """
    Simple multiplication task used as a building block for workflow composition.
    
    This lightweight task demonstrates how simple operations can be
    combined into complex workflows using Celery's primitives (chain,
    group, chord). Fast execution makes it ideal for testing workflow
    patterns without long wait times.
    
    Args:
        x (int): First number to multiply
        y (int): Second number to multiply
    
    Returns:
        int: Product of x and y
        
    Workflow Usage Examples:
        - Chain: add(2, 3) -> multiply(result, 2) = 10
        - Group: [multiply(1,2), multiply(3,4), multiply(5,6)]
        - Chord: parallel multiplications -> aggregate results
        
    Use cases:
        - Mathematical calculations in workflows
        - Data transformation pipelines
        - Testing workflow composition
        - Building complex business logic from simple operations
    """
    return x * y

@celery_app.task
def summarize(numbers: list):
    """
    Aggregation task for collecting and processing results from parallel tasks.
    
    This task serves as a callback/reducer function in Celery workflows,
    particularly useful in chord and group patterns where multiple tasks
    run in parallel and their results need to be combined.
    
    Args:
        numbers (list): List of numbers to sum
                       Typically results from parallel task execution
    
    Returns:
        int: Sum of all numbers in the list, or 0 for empty list
        
    Workflow Patterns:
        1. Chord: [task1, task2, task3] -> summarize(results)
        2. Group: parallel tasks -> collect results -> summarize
        3. Map-Reduce: map phase (parallel) -> reduce phase (summarize)
        
    Error Handling:
        - Handles empty lists gracefully
        - Could be extended to handle failed task results
        - Type validation could be added for robustness
        
    Use cases:
        - Aggregating parallel computation results
        - Calculating totals from distributed processing
        - Collecting metrics from multiple sources
        - Final step in map-reduce operations
        - Combining results from batch processing
    """
    return sum(numbers) if numbers else 0

@celery_app.task
def run_chain(x: int, y: int):
    """
    Demonstrates Celery's chain primitive for sequential task execution.
    
    Chains create pipelines where each task's output becomes the input
    for the next task. This enables complex data processing workflows
    where operations must happen in a specific order.
    
    Chain Flow:
        1. add(x, y) executes first
        2. Result passed to multiply(result, 2)
        3. Final result returned
        
    Example: run_chain(3, 4)
        -> add(3, 4) = 7
        -> multiply(7, 2) = 14
        -> Final result: 14
    
    Args:
        x (int): First number for initial add operation
        y (int): Second number for initial add operation
    
    Returns:
        int: Final result after chain execution
        
    Advanced Chain Features:
        - Partial application: chain(add.s(1), multiply.s(2))
        - Error handling: if any task fails, chain stops
        - Immutable signatures: tasks can be pre-configured
        
    Use cases:
        - Data processing pipelines
        - Multi-step calculations
        - Workflow orchestration
        - ETL (Extract, Transform, Load) operations
        - Sequential API calls where each depends on the previous
    """
    # Create chain: add task followed by multiply task
    result = chain(add.s(x, y), multiply.s(2))
    return result.apply_async()  # Execute the chain and return AsyncResult

@celery_app.task
def run_chord(numbers: list):
    """
    Demonstrates Celery's chord primitive for parallel-then-aggregate workflows.
    
    Chords implement the "map-reduce" pattern:
    1. Header: Multiple tasks run in parallel (map phase)
    2. Body: Single callback task processes all results (reduce phase)
    
    Chord Components:
        - Header: List of tasks to run in parallel
        - Body: Callback task that receives all header results
        
    Execution Flow:
        1. All header tasks (add operations) start simultaneously
        2. Celery waits for ALL header tasks to complete
        3. All results collected into a list
        4. Body task (summarize) executes with collected results
    
    Args:
        numbers (list): List of numbers to process in parallel
    
    Returns:
        int: Aggregated result from parallel processing
        
    Example: run_chord([1, 2, 3])
        -> Parallel: [add(1,1), add(2,1), add(3,1)] = [2, 3, 4]
        -> Callback: summarize([2, 3, 4]) = 9
    
    Error Handling:
        - If any header task fails, entire chord fails
        - Body task won't execute if header fails
        - Consider error handling strategies for robustness
        
    Use cases:
        - Parallel data processing with aggregation
        - Distributed calculations
        - Batch processing with result compilation
        - Performance optimization for independent operations
        - Map-reduce style algorithms
    """
    # Create header: parallel add tasks for each number
    header = [add.s(n, 1) for n in numbers]
    # Execute chord: header tasks in parallel, then summarize callback
    result = chord(header)(summarize.s())
    return result  # Return task ID instead of blocking

@celery_app.task
def run_group(numbers: list):
    """
    Demonstrates Celery's group primitive for parallel task execution.
    
    Groups execute multiple tasks simultaneously without dependencies.
    Unlike chords, groups don't automatically have a callback - the
    calling code handles result collection and processing.
    
    Group Characteristics:
        - All tasks start immediately
        - No automatic result aggregation
        - Caller responsible for collecting results
        - Better performance for independent operations
    
    Args:
        numbers (list): List of numbers to process in parallel
    
    Returns:
        int: Sum of all parallel task results
        
    Example: run_group([1, 2, 3])
        -> Parallel: [add(1,1), add(2,1), add(3,1)] = [2, 3, 4]
        -> Manual aggregation: sum([2, 3, 4]) = 9
    
    Comparison with Chord:
        - Group: More flexible, manual result handling
        - Chord: Automatic aggregation, simpler for map-reduce
        
    Performance Benefits:
        - All tasks execute truly in parallel
        - No waiting for synchronization point
        - Optimal for independent operations
        - Can process results as they complete
        
    Use cases:
        - Parallel API calls
        - Independent calculations
        - Batch processing without aggregation
        - When you need custom result handling
        - Performance-critical parallel operations
    """
    # Create group of parallel add tasks
    tasks = [add.s(n, 1) for n in numbers]
    # Execute group and manually aggregate results
    result = group(tasks)
    return result.apply_async()  # Return task ID instead of blocking

@celery_app.task
def notify_success(result):
    """
    Success callback task for handling successful task completion.
    
    Callback tasks enable event-driven architectures where task completion
    triggers additional actions. This creates loosely coupled systems where
    tasks can have side effects without direct coupling.
    
    Callback Characteristics:
        - Executes only after successful task completion
        - Receives the result of the completed task
        - Runs asynchronously as a separate task
        - Can trigger additional workflows
    
    Args:
        result: The return value from the successfully completed task
    
    Use Cases:
        - Sending notifications (email, SMS, push)
        - Logging successful operations
        - Updating user interfaces
        - Triggering dependent workflows
        - Auditing and compliance recording
        - Cache invalidation
        - Metrics and analytics collection
        
    Integration Example:
        task.apply_async(link=notify_success.s())
        
    Advanced Patterns:
        - Chain success callbacks: success1 -> success2 -> success3
        - Conditional callbacks based on result content
        - Fan-out: one task triggers multiple callbacks
    """
    print(f"Task completed successfully: {result}")

@celery_app.task
def notify_failure(task_id, exc):
    """
    Error callback task for handling task failures and exceptions.
    
    Failure callbacks implement robust error handling patterns in
    distributed systems. They enable centralized error processing,
    alerting, and recovery mechanisms.
    
    Callback Execution:
        - Triggers when linked task raises an exception
        - Executes even if the main task exhausts all retries
        - Runs as a separate task (asynchronous)
        - Receives task metadata and exception information
    
    Args:
        task_id (str): Unique identifier of the failed task
        exc (Exception): The exception that caused the failure
    
    Error Handling Strategies:
        1. Logging: Record failure details for debugging
        2. Alerting: Notify administrators of critical failures
        3. Compensation: Trigger rollback or cleanup tasks
        4. Recovery: Attempt alternative processing methods
        5. Circuit Breaking: Disable failing service temporarily
        
    Integration Example:
        task.apply_async(link_error=notify_failure.s())
        
    Use Cases:
        - System monitoring and alerting
        - Error logging and debugging
        - Automatic issue creation
        - Rollback operations
        - Alternative workflow triggering
        - Failure metrics collection
        - Dead letter queue processing
    """
    print(f"Task {task_id} failed with exception: {exc}")

@celery_app.task
def risky_task(x: int):
    """
    Task with conditional failure logic for testing error handling mechanisms.
    
    This task simulates real-world scenarios where tasks can fail based on
    input validation, business rules, or external conditions. It's designed
    to test callback systems and error handling patterns.
    
    Failure Condition:
        - Raises ValueError for negative input values
        - Simulates input validation failures
        - Represents business rule violations
    
    Args:
        x (int): Input value to process and validate
                Negative values trigger failure condition
    
    Returns:
        int: Double the input value for valid (non-negative) inputs
        
    Raises:
        ValueError: When input is negative (x < 0)
        
    Testing Scenarios:
        1. Success: risky_task(5) -> returns 10
        2. Failure: risky_task(-3) -> raises ValueError
        3. Edge case: risky_task(0) -> returns 0
        
    Error Simulation:
        This represents common failure patterns:
        - Input validation errors
        - Business rule violations  
        - Precondition failures
        - Data quality issues
        
    Use Cases:
        - Testing callback mechanisms
        - Validating error handling
        - Demonstrating failure propagation
        - Training error recovery systems
    """
    if x < 0:
        # Simulate validation failure for negative inputs
        raise ValueError("Negative value error")
    return x * 2  # Normal processing for valid inputs

@celery_app.task
def run_with_callbacks(x):
    """
    Demonstrates comprehensive task linking with success and error callbacks.
    
    This function showcases how to build robust, event-driven task systems
    where task completion (success or failure) automatically triggers
    appropriate response actions. This pattern is essential for building
    resilient distributed systems.
    
    Callback Linking:
        - link: Executes on successful task completion
        - link_error: Executes on task failure or exception
        - Both callbacks run as separate asynchronous tasks
        
    Args:
        x (int): Input value passed to risky_task
                Success/failure depends on whether x is negative
    
    Returns:
        AsyncResult: Celery result object for monitoring task execution
        
    Execution Scenarios:
        1. Success (x >= 0):
           - risky_task executes successfully
           - notify_success callback triggered with result
           - notify_failure callback NOT executed
           
        2. Failure (x < 0):
           - risky_task raises ValueError
           - notify_failure callback triggered with exception
           - notify_success callback NOT executed
    
    Callback Chain Flow:
        risky_task(x) -> [SUCCESS] -> notify_success(result)
                      -> [FAILURE] -> notify_failure(task_id, exc)
    
    Advanced Patterns:
        - Multiple callbacks: link=[callback1.s(), callback2.s()]
        - Conditional callbacks based on result values
        - Callback chains: callbacks that trigger other callbacks
        - Mixed success/error handling in complex workflows
        
    Use Cases:
        - Order processing with payment callbacks
        - File processing with success/failure notifications
        - API integrations with error handling
        - Workflow orchestration with event triggers
        - Audit trails for business processes
        - Real-time user notifications
    """
    return risky_task.s(x).apply_async(
        link=notify_success.s(),        # Success callback
        link_error=notify_failure.s()   # Error callback
    )

@celery_app.task(rate_limit='10/m')
def limited_task(x):
    """
    Rate-limited task demonstrating Celery's built-in throttling capabilities.
    
    Rate limiting is crucial for protecting external services, managing
    resource consumption, and ensuring fair usage in multi-tenant systems.
    Celery provides flexible rate limiting at the task level.
    
    Rate Limit Configuration:
        - '10/m': Maximum 10 executions per minute
        - '100/h': 100 executions per hour
        - '10/s': 10 executions per second
        - '1/d': 1 execution per day
        
    Rate Limiting Behavior:
        - Tasks exceeding the rate are queued, not rejected
        - Workers automatically enforce rate limits
        - Rate limits are per-worker, not global
        - Excess tasks wait until rate limit window resets
    
    Args:
        x: Input value to process (any type)
    
    Returns:
        str: Formatted message confirming processing
        
    Rate Limiting Strategies:
        1. API Protection: Prevent overwhelming external services
        2. Resource Management: Control CPU/memory intensive tasks
        3. Fair Usage: Ensure equitable resource distribution
        4. Cost Control: Limit expensive operations
        
    Global Rate Limiting:
        For system-wide limits, implement custom rate limiting:
        - Redis-based counters
        - Database rate tracking
        - External rate limiting services
        
    Monitoring:
        - Track rate limit violations
        - Monitor queue buildup due to rate limiting
        - Adjust limits based on system capacity
        
    Use Cases:
        - API call throttling
        - Email sending limits
        - Database query rate limiting
        - External service integration
        - Resource-intensive operations
        - Cost-sensitive operations (cloud API calls)
    """
    return f"Processed {x}"