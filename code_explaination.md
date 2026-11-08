# Complete line-by-line explanation of your ESP32 micro-ROS code

Your program turns the ESP32 into a ROS 2 node that communicates wirelessly over Wi-Fi using micro-ROS and UDP.

It performs two operations simultaneously:

1. ESP32 → ROS 2: Publishes an incrementing counter every second.
2. ROS 2 → ESP32: Receives Boolean commands and switches the onboard LED ON or OFF.

Let's understand every section, including the purpose of the functions, variables, macros and execution flow.

## 1. Header files and libraries

```
#include <Arduino.h>
#include <WiFi.h>

#include <micro_ros_platformio.h>

#include <rcl/rcl.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/bool.h>

#include "config.h"
```

| Header                   | Purpose                                                                                                          |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `Arduino.h`              | Provides Arduino functions such as `setup()`, `loop()`, `pinMode()`, `digitalWrite()`, `millis()` and `delay()`. |
| `WiFi.h`                 | Provides ESP32 Wi-Fi functionality.                                                                              |
| `micro_ros_platformio.h` | Provides the micro-ROS transport integration for PlatformIO.                                                     |
| `rcl/rcl.h`              | Provides the ROS Client Library (RCL), including node, publisher, subscriber and message operations.             |
| `rclc/rclc.h`            | Provides the RCL C convenience API for initializing ROS 2 entities.                                              |
| `rclc/executor.h`        | Provides the executor, which processes incoming messages and invokes callbacks.                                  |
| `std_msgs/msg/int32.h`   | Defines the ROS 2 `Int32` message type.                                                                          |
| `std_msgs/msg/bool.h`    | Defines the ROS 2 `Bool` message type.                                                                           |
| `config.h`               | Your custom configuration file containing Wi-Fi credentials, Agent IP, port and LED pin.                         |

Important distinction: `rcl` is the lower-level ROS Client Library, while `rclc` provides a simpler C API for working with ROS entities.

## 2. micro-ROS objects

```
rcl_allocator_t allocator;
rclc_support_t support;
```

These two objects are required to initialize the micro-ROS environment.

`rcl_allocator_t allocator`

- Allocator manages dynamic memory allocation.
- ROS 2 internally requires memory for nodes, publishers, subscriptions and other entities.
- You use the default allocator later.

`rclc_support_t support`

- Stores the support context for your micro-ROS application.
- Contains information required to initialize ROS entities.
- Acts as the foundation for creating your node.

Next:

```
rcl_node_t node;
rcl_publisher_t counter_publisher;
rcl_subscription_t led_subscription;
```

These represent three important ROS 2 entities.

| Object              | ROS 2 concept | Purpose                                   |
| ------------------- | ------------- | ----------------------------------------- |
| `node`              | Node          | Represents your ESP32 in the ROS 2 graph. |
| `counter_publisher` | Publisher     | Publishes counter values.                 |
| `led_subscription`  | Subscriber    | Receives LED commands.                    |

Your node name is configured later as:

```
esp32_node
```

Next:

```
rclc_executor_t executor;
```

The executor is responsible for processing incoming ROS messages.

Think of it as the message-processing engine.

For example:

1. ROS 2 sends `true` to `/esp32/led_command`.
2. The message reaches the ESP32 through the Agent.
3. The executor detects the incoming message.
4. The executor invokes `led_callback()`.
5. The callback turns the LED ON.

Without the executor being spun, your subscriber callback would not be processed.

Next:

```
std_msgs__msg__Int32 counter_message;
std_msgs__msg__Bool led_message;
```

These are the actual message objects.

- `counter_message` stores the integer you want to publish.
- `led_message` stores the Boolean message received from ROS 2.

Notice the naming convention:

| ROS 2 message        | C representation       |
| -------------------- | ---------------------- |
| `std_msgs/msg/Int32` | `std_msgs__msg__Int32` |
| `std_msgs/msg/Bool`  | `std_msgs__msg__Bool`  |

The double underscore is part of the generated C message naming convention.

## 3. Error-handling macros

Your code defines two macros:

### A. RCCHECK()

```
#define RCCHECK(fn)                                      \
  do {                                                   \
    rcl_ret_t rc = (fn);                                 \
    if (rc != RCL_RET_OK) {                              \
      error_loop();                                      \
    }                                                    \
  } while (0)
```

Let's break it down.

`#define RCCHECK(fn)`

Creates a macro named `RCCHECK` that accepts a function call as an argument.

For example:

```
RCCHECK(rclc_support_init(...));
```

`rcl_ret_t rc = (fn);`

- Executes the supplied ROS function.
- Stores its return value in `rc`.
- `rcl_ret_t` is the return type used by the ROS Client Library.

`if (rc != RCL_RET_OK)`

Checks whether the operation failed.

`RCL_RET_OK` represents successful execution.

`error_loop();`

If initialization fails, the ESP32 enters a permanent error loop.

Why use this?

Suppose the ROS node cannot be created. Continuing to execute the program without a valid node would cause further errors.

### B. RCSOFTCHECK()

```
#define RCSOFTCHECK(fn)                                  \
  do {                                                   \
    rcl_ret_t rc = (fn);                                 \
    if (rc != RCL_RET_OK) {                              \
      Serial.print("micro-ROS error: ");                 \
      Serial.println(rc);                                \
    }                                                    \
  } while (0)
```

This macro is less strict.

It:

1. Executes the ROS function.
2. Checks its return value.
3. Prints the error code if the operation fails.
4. Continues executing the program.

You use it for publishing and processing incoming messages.

Difference:

| Macro           | Behaviour after error      | Intended use            |
| --------------- | -------------------------- | ----------------------- |
| `RCCHECK()`     | Stops execution            | Critical initialization |
| `RCSOFTCHECK()` | Prints error and continues | Runtime operations      |

### C. error_loop()

```
void error_loop()
{
  Serial.println("Fatal micro-ROS initialization error");

  while (true) {
    delay(100);
  }
}
```

This is a normal C++ function.

- Prints an error message.
- Enters an infinite loop.
- `delay(100)` pauses execution for 100 milliseconds in each iteration.

This prevents the ESP32 from continuing with an incorrectly initialized micro-ROS system.

## 4. Subscriber callback

This is one of the most important sections.

```
void led_callback(const void * msgin)
```

This function executes when the ESP32 receives a new message on the subscribed topic.

Let's understand the arguments.

- `void` means the function does not return a value.
- `const void * msgin` is a pointer to the incoming message.
- `const` means the callback should not modify the received message through this pointer.
- `void *` is a generic pointer, so we need to convert it into the appropriate message type.

Next:

```
const std_msgs__msg__Bool * msg =
      (const std_msgs__msg__Bool *)msgin;
```

This converts the generic pointer into a Boolean message pointer.

Why?

Because your subscriber expects:

```
std_msgs/msg/Bool
```

The message contains one field:

```
bool data;
```

You can access it using:

```
msg->data
```

Next:

```
digitalWrite(
      LED_PIN,
      msg->data ? HIGH : LOW
);
```

This is a conditional expression, also called the ternary operator.

Its syntax is:

```
condition ? value_if_true : value_if_false;
```

Therefore:

- If `msg->data == true`, the LED pin becomes HIGH.
- If `msg->data == false`, the LED pin becomes LOW.

Finally:

```
Serial.print("LED command received: ");
Serial.println(msg->data ? "ON" : "OFF");
```

Prints the received command on the serial monitor.

For example:

```
LED command received: ON
LED command received: OFF
```

The important concept: The callback does not continuously check the topic. The executor invokes it when a new message is received.

## 5. Initializing micro-ROS

Now we reach the most important function:

```
void init_microros()
```

This function establishes the connection and creates all ROS entities.

### A. Configure the Agent IP

```
IPAddress agent_ip(
      AGENT_IP_1,
      AGENT_IP_2,
      AGENT_IP_3,
      AGENT_IP_4
);
```

Creates an IP address object.

For example, if your configuration contains:

```
#define AGENT_IP_1 192
#define AGENT_IP_2 168
#define AGENT_IP_3 0
#define AGENT_IP_4 103
```

Then:

```
agent_ip = 192.168.0.103
```

This is the IP address of the computer running your micro-ROS Agent.

### B. Configure Wi-Fi credentials

```
static char ssid[] = WIFI_SSID;
static char password[] = WIFI_PASSWORD;
```

These variables store your Wi-Fi SSID and password.

The `static` keyword gives these arrays static storage duration, so they remain valid after the function returns.

This is useful because the transport may retain references to the supplied credentials during its operation.

### C. Configure Wi-Fi UDP transport

```
set_microros_wifi_transports(
      ssid,
      password,
      agent_ip,
      AGENT_PORT
);
```

This is where you configure the ESP32's micro-ROS transport.

It supplies:

1. Wi-Fi network name.
2. Wi-Fi password.
3. Agent IP address.
4. Agent UDP port.

Your setup uses UDP communication.

The architecture looks like this:

ESP32

micro-ROS client

Wi-Fi / UDP

XRCE-DDS communication

micro-ROS Agent

Docker container · UDP port 8888

ROS 2 Jazzy

Nodes, topics, publishers and subscribers

The Agent acts as a bridge between the micro-ROS client and the ROS 2 system.

Next:

```
delay(2000);
```

Waits for two seconds.

This gives the ESP32 some time to establish the Wi-Fi connection and configure the transport.

Note that this delay is not itself a definitive check that the Agent is reachable.

### D. Initialize the allocator

```
allocator = rcl_get_default_allocator();
```

Gets the default memory allocator provided by the ROS Client Library.

The allocator is needed when creating ROS entities.

### E. Initialize micro-ROS support

```
RCCHECK(
      rclc_support_init(
          &support,
          0,
          NULL,
          &allocator
      )
);
```

This initializes the micro-ROS support context.

Let's understand each argument:

| Argument     | Meaning                                      |
| ------------ | -------------------------------------------- |
| `&support`   | Address of the support object to initialize. |
| `0`          | Number of command-line arguments.            |
| `NULL`       | No command-line argument array.              |
| `&allocator` | Address of the memory allocator.             |

The `&` operator passes the address of a variable.

The `RCCHECK()` macro checks whether initialization succeeds.

### F. Create the ROS 2 node

```
RCCHECK(
      rclc_node_init_default(
          &node,
          "esp32_node",
          "",
          &support
      )
);
```

Creates your ROS 2 node.

Arguments:

| Argument       | Meaning                          |
| -------------- | -------------------------------- |
| `&node`        | Node object to initialize.       |
| `"esp32_node"` | Node name.                       |
| `""`           | Empty namespace.                 |
| `&support`     | Initialized ROS support context. |

Your ROS 2 graph will contain:

```
/esp32_node
```

The node is the main logical entity representing your ESP32 application.

## 6. Creating the publisher

```
RCCHECK(
      rclc_publisher_init_default(
          &counter_publisher,
          &node,
          ROSIDL_GET_MSG_TYPE_SUPPORT(
              std_msgs,
              msg,
              Int32
          ),
          "/esp32/counter"
      )
);
```

This creates a ROS 2 publisher.

Let's understand the arguments.

`&counter_publisher`

The publisher object that will be initialized.

`&node`

The node that owns this publisher.

`ROSIDL_GET_MSG_TYPE_SUPPORT(...)`

This macro retrieves the generated message type-support information required by ROS 2.

Its arguments are:

```
std_msgs,
msg,
Int32
```

Together, they identify:

```
std_msgs/msg/Int32
```

`"/esp32/counter"`

This is the topic name.

Your ESP32 publishes integer values to this topic.

In ROS 2, you can receive those values using:

```
ros2 topic echo /esp32/counter
```

For example:

```
data: 1
---
data: 2
---
data: 3
```

## 7. Creating the subscriber

```
RCCHECK(
      rclc_subscription_init_default(
          &led_subscription,
          &node,
          ROSIDL_GET_MSG_TYPE_SUPPORT(
              std_msgs,
              msg,
              Bool
          ),
          "/esp32/led_command"
      )
);
```

This creates your ROS 2 subscriber.

Arguments:

| Argument            | Meaning                         |
| ------------------- | ------------------------------- |
| `&led_subscription` | Subscriber object.              |
| `&node`             | Node that owns the subscriber.  |
| Type support        | Identifies `std_msgs/msg/Bool`. |
| Topic name          | `/esp32/led_command`.           |

The subscriber listens for Boolean messages.

You can send a command from Ubuntu using:

```
ros2 topic pub --once /esp32/led_command std_msgs/msg/Bool "{data: true}"
```

The ESP32 receives this message and invokes `led_callback()`.

## 8. Initializing the executor

```
RCCHECK(
      rclc_executor_init(
          &executor,
          &support.context,
          1,
          &allocator
      )
);
```

This initializes the executor.

Arguments:

| Argument           | Meaning                           |
| ------------------ | --------------------------------- |
| `&executor`        | Executor object.                  |
| `&support.context` | ROS context used by the executor. |
| `1`                | Number of handles to manage.      |
| `&allocator`       | Memory allocator.                 |

What is a handle?

In this example, a handle is an entity registered with the executor for event processing.

You have registered only one handle: the LED subscriber.

That's why the number is `1`.

If you later add another subscription, you will need to increase the executor capacity accordingly.

### Registering the callback

```
RCCHECK(
      rclc_executor_add_subscription(
          &executor,
          &led_subscription,
          &led_message,
          &led_callback,
          ON_NEW_DATA
      )
);
```

This connects your subscriber to your callback.

| Argument            | Meaning                                       |
| ------------------- | --------------------------------------------- |
| `&executor`         | Executor responsible for processing messages. |
| `&led_subscription` | Subscriber being registered.                  |
| `&led_message`      | Memory where incoming messages are stored.    |
| `&led_callback`     | Function to execute when a message arrives.   |
| `ON_NEW_DATA`       | Invoke callback when new data is available.   |

The complete process is:

```
ROS 2 publishes a Boolean message
              |
              v
      ESP32 receives data
              |
              v
      Executor detects data
              |
              v
       led_callback()
              |
              v
       digitalWrite()
              |
              v
          LED ON/OFF
```

### Initialize message values

```
counter_message.data = 0;
led_message.data = false;
```

- Counter starts at zero.
- LED message storage starts with `false`.

These are initial message values, not commands sent to ROS 2.

Finally:

```
Serial.println("micro-ROS initialization complete");
```

Prints a message indicating that the initialization sequence has completed.

## 9. Arduino setup()

```
void setup()
{
  Serial.begin(115200);
  delay(1500);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println();
  Serial.println("Starting ESP32 micro-ROS node");

  init_microros();
}
```

The Arduino `setup()` function executes only once after the ESP32 starts or resets.

Line by line:

`Serial.begin(115200);`

Initializes serial communication at 115200 baud.

`delay(1500);`

Waits 1.5 seconds, allowing the serial monitor to connect.

`pinMode(LED_PIN, OUTPUT);`

Configures the LED pin as an output.

`digitalWrite(LED_PIN, LOW);`

Turns the LED OFF initially.

`Serial.println();`

Prints an empty line.

`Serial.println("Starting ESP32 micro-ROS node");`

Prints the startup message.

`init_microros();`

Initializes Wi-Fi transport, ROS support, node, publisher, subscriber and executor.

After `setup()` finishes, Arduino starts repeatedly executing `loop()`.

## 10. Main loop()

This is where your program continuously operates.

```
void loop()
{
  static unsigned long previous_time = 0;
```

Declares a variable that stores the time when the counter was last published.

- `unsigned long` stores a non-negative integer.
- `static` means the variable retains its value between calls to `loop()`.
- Initial value is zero.

Without `static`, this variable would be reset every time `loop()` executes.

### A. Process incoming ROS messages

```
RCSOFTCHECK(
      rclc_executor_spin_some(
          &executor,
          RCL_MS_TO_NS(10)
      )
);
```

This is one of the most important lines in the entire program.

`rclc_executor_spin_some()` checks for available messages and processes them.

Arguments:

`&executor`

Specifies which executor should process messages.

`RCL_MS_TO_NS(10)`

Converts 10 milliseconds into nanoseconds.

Why?

ROS 2 represents timeout durations in nanoseconds.

\\[ 10\text{ ms}=10,000,000\text{ ns} \\]

The executor uses this timeout while checking and processing available work.

If a message is available, it invokes the registered callback.

If no message is available, execution continues.

`RCSOFTCHECK()` prints an error if the executor operation fails.

### B. Get the current time

```
unsigned long current_time = millis();
```

`millis()` returns the number of milliseconds since the ESP32 started running the program.

For example:

```
current_time = 1000
current_time = 2000
current_time = 3000
```

### C. Check whether one second has passed

```
if (current_time - previous_time >= 1000) {
```

Checks whether at least 1000 milliseconds have elapsed since the previous publication.

\\[ 1000\text{ ms}=1\text{ second} \\]

This allows you to publish once per second without using a one-second blocking delay.

### D. Update the previous timestamp

```
previous_time = current_time;
```

Stores the current time so the next publication happens approximately one second later.

### E. Increment the counter

```
counter_message.data++;
```

Increments the integer message value by one.

For example:

```
0 → 1 → 2 → 3 → 4 → 5
```

### F. Publish the message

```
RCSOFTCHECK(
      rcl_publish(
          &counter_publisher,
          &counter_message,
          NULL
      )
);
```

This sends the message to ROS 2.

Arguments:

| Argument             | Meaning                                                            |
| -------------------- | ------------------------------------------------------------------ |
| `&counter_publisher` | Publisher responsible for sending the message.                     |
| `&counter_message`   | Message containing the integer value.                              |
| `NULL`               | No separate allocation or custom publication options are supplied. |

For example, if:

```
counter_message.data = 25;
```

Then ROS 2 receives:

```
data: 25
```

### G. Print the counter

```
Serial.print("Published counter: ");
Serial.println(counter_message.data);
```

Displays the counter value on the serial monitor.

Example:

```
Published counter: 1
Published counter: 2
Published counter: 3
```

### H. Small delay

```
delay(5);
```

Pauses execution for approximately 5 milliseconds.

This prevents the loop from running continuously at maximum speed.

It also leaves a little processing time for other operations.

# 11. Complete program execution flow

Let's put everything together.

ESP32 starts

Power ON / Reset

setup()

Initialize Serial and LED pin

init_microros()

Configure Wi-Fi, Agent transport, node, publisher, subscriber and executor

loop() — Repeats continuously

Incoming messages

Executor spins → callback → LED ON/OFF

Outgoing messages

Check elapsed time → increment counter → publish

Both operations continue as loop() repeats.

# 12. ROS 2 commands corresponding to your code

These commands directly interact with the topics you created.

| Purpose               | Command                                                                      |
| --------------------- | ---------------------------------------------------------------------------- |
| List nodes            | `ros2 node list`                                                             |
| Inspect ESP32 node    | `ros2 node info /esp32_node`                                                 |
| List topics           | `ros2 topic list -t`                                                         |
| Read counter          | `ros2 topic echo /esp32/counter`                                             |
| Inspect counter topic | `ros2 topic info /esp32/counter`                                             |
| Turn LED ON           | `ros2 topic pub --once /esp32/led_command std_msgs/msg/Bool "{data: true}"`  |
| Turn LED OFF          | `ros2 topic pub --once /esp32/led_command std_msgs/msg/Bool "{data: false}"` |

# 13. Important limitations in your current code

Your program works, but there are some things you should understand before using this architecture in a robotics or drone project.

| Current implementation              | Limitation                                                                              |
| ----------------------------------- | --------------------------------------------------------------------------------------- |
| `delay(5)`                          | Blocks execution briefly.                                                               |
| Fixed 2-second initialization delay | Does not verify Agent availability.                                                     |
| `RCSOFTCHECK()`                     | Prints runtime errors but does not recover from them.                                   |
| No Agent connection monitoring      | Does not explicitly handle disconnection and reconnection.                              |
| No publisher/subscriber cleanup     | No graceful ROS entity destruction.                                                     |
| No command timeout                  | A previously received command can remain the last applied state if communication stops. |

For your future drone integration, one particularly important improvement is a communication watchdog.

For example, if the ESP32 stops receiving valid commands for 500 milliseconds, it should detect the timeout and enter a predefined safe state. The flight controller's stabilization and motor failsafe logic must remain independent of ROS 2 communication.