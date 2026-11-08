# ESP32 micro-ROS Publisher and Subscriber (ROS 2 Jazzy)

This project demonstrates how to set up an ESP32 as a micro-ROS node communicating with a ROS 2 Jazzy host over Wi-Fi. The ESP32 node runs a publisher that increments a counter every second, and a subscriber that toggles the onboard LED based on received commands.

## Prerequisites & Environment Setup

Before running this project, you need to set up your Ubuntu 24.04 environment. This repository includes three automated bash scripts to install all the necessary dependencies.

To execute them, open your terminal in the folder containing the scripts and run:

```bash
# Make the scripts executable
chmod +x ros2-installation.sh docker-installation.sh platformio-installation.sh

# 1. Install ROS 2 Jazzy
./ros2-installation.sh

# 2. Install and configure Docker
./docker-installation.sh

# 3. Install VS Code and PlatformIO
./platformio-installation.sh
```
*Note: Make sure to apply the `source ~/.bashrc` command or open a new terminal after running the installations to apply the PATH and ROS 2 environment variables.*

## Project Structure & Source Code

Create a new folder for your project and set up the following directory structure with the provided code.

```text
├── include
│   └── config.h      # Wi-Fi and Agent IP configurations
├── src
│   └── main.cpp      # Main application code (Node, Publisher, Subscriber)
└── platformio.ini    # PlatformIO configuration
```

### 1. `platformio.ini`
Create this file in the root of your project directory:

```ini
[env:esp32dev]

platform = espressif32@7.1.3
board = esp32dev
framework = arduino

monitor_speed = 115200
upload_speed = 921600

lib_deps =
    https://github.com/micro-ROS/micro_ros_platformio

board_microros_distro = jazzy
board_microros_transport = wifi

build_flags =
    -DCORE_DEBUG_LEVEL=3
```

### 2. `include/config.h`
Create the `include` folder and add `config.h`:

```cpp
#ifndef CONFIG_H
#define CONFIG_H

// Wi-Fi network credentials
#define WIFI_SSID     "WIFI_SSID"
#define WIFI_PASSWORD "WIFI_PASSWORD"

// IPv4 address of the Ubuntu computer running the Agent
#define AGENT_IP_1 192
#define AGENT_IP_2 168
#define AGENT_IP_3 0
#define AGENT_IP_4 103

// micro-ROS Agent UDP port
#define AGENT_PORT 8888

// ESP32 onboard LED pin for the example.
// Verify this pin for your exact board.
#define LED_PIN 2

#endif
```

### 3. `src/main.cpp`
Create the `src` folder and add `main.cpp`:

```cpp
#include <Arduino.h>
#include <WiFi.h>

#include <micro_ros_platformio.h>

#include <rcl/rcl.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/bool.h>

#include "config.h"

// --------------------------------------------------
// 1. micro-ROS objects
// --------------------------------------------------

rcl_allocator_t allocator;
rclc_support_t support;

rcl_node_t node;
rcl_publisher_t counter_publisher;
rcl_subscription_t led_subscription;

rclc_executor_t executor;

std_msgs__msg__Int32 counter_message;
std_msgs__msg__Bool led_message;

// --------------------------------------------------
// 2. Error handling
// --------------------------------------------------

#define RCCHECK(fn)                                      \
  do {                                                   \
    rcl_ret_t rc = (fn);                                 \
    if (rc != RCL_RET_OK) {                              \
      error_loop();                                      \
    }                                                    \
  } while (0)

#define RCSOFTCHECK(fn)                                  \
  do {                                                   \
    rcl_ret_t rc = (fn);                                 \
    if (rc != RCL_RET_OK) {                              \
      Serial.print("micro-ROS error: ");                 \
      Serial.println(rc);                                \
    }                                                    \
  } while (0)

void error_loop()
{
  Serial.println("Fatal micro-ROS initialization error");

  while (true) {
    delay(100);
  }
}

// --------------------------------------------------
// 3. Subscriber callback
// --------------------------------------------------

void led_callback(const void * msgin)
{
  const std_msgs__msg__Bool * msg =
      (const std_msgs__msg__Bool *)msgin;

  digitalWrite(
      LED_PIN,
      msg->data ? HIGH : LOW
  );

  Serial.print("LED command received: ");
  Serial.println(msg->data ? "ON" : "OFF");
}

// --------------------------------------------------
// 4. Initialize micro-ROS
// --------------------------------------------------

void init_microros()
{
  // Set up Wi-Fi and micro-ROS UDP transport.
  IPAddress agent_ip(
      AGENT_IP_1,
      AGENT_IP_2,
      AGENT_IP_3,
      AGENT_IP_4
  );

  static char ssid[] = WIFI_SSID;
  static char password[] = WIFI_PASSWORD;

  set_microros_wifi_transports(
      ssid,
      password,
      agent_ip,
      AGENT_PORT
  );

  delay(2000);

  allocator = rcl_get_default_allocator();

  // Initialize micro-ROS support.
  RCCHECK(
      rclc_support_init(
          &support,
          0,
          NULL,
          &allocator
      )
  );

  // Create the ESP32 ROS 2 node.
  RCCHECK(
      rclc_node_init_default(
          &node,
          "esp32_node",
          "",
          &support
      )
  );

  // Create an Int32 publisher.
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

  // Create a Bool subscriber.
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

  // Initialize the executor with one subscription handle.
  RCCHECK(
      rclc_executor_init(
          &executor,
          &support.context,
          1,
          &allocator
      )
  );

  // Register the subscriber callback.
  RCCHECK(
      rclc_executor_add_subscription(
          &executor,
          &led_subscription,
          &led_message,
          &led_callback,
          ON_NEW_DATA
      )
  );

  counter_message.data = 0;
  led_message.data = false;

  Serial.println("micro-ROS initialization complete");
}

// --------------------------------------------------
// 5. Arduino setup
// --------------------------------------------------

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

// --------------------------------------------------
// 6. Main loop
// --------------------------------------------------

void loop()
{
  static unsigned long previous_time = 0;

  // Process incoming ROS 2 messages.
  RCSOFTCHECK(
      rclc_executor_spin_some(
          &executor,
          RCL_MS_TO_NS(10)
      )
  );

  // Publish counter once per second.
  unsigned long current_time = millis();

  if (current_time - previous_time >= 1000) {

    previous_time = current_time;

    counter_message.data++;

    RCSOFTCHECK(
        rcl_publish(
            &counter_publisher,
            &counter_message,
            NULL
        )
    );

    Serial.print("Published counter: ");
    Serial.println(counter_message.data);
  }

  delay(5);
}
```

## Step 1: Configuration

Before building the project, you must update the network credentials in `include/config.h` so the ESP32 can connect to your Wi-Fi and find your Ubuntu machine.

1. Update the Wi-Fi credentials to match your local network.
2. Update the `AGENT_IP` to match the IPv4 address of your Ubuntu machine (find this by running `ip a` or `ifconfig` in your Ubuntu terminal).

## Step 2: Build and Upload using PlatformIO

You can use the PlatformIO CLI to compile the code, flash it to your ESP32, and view the serial output. Connect your ESP32 via USB and run the following commands in your project directory:

**1. Build the project:**
```bash
pio run
```

**2. Upload the firmware to the ESP32:**
```bash
pio run -t upload
```

**3. Open the Serial Monitor:**
```bash
pio device monitor -b 115200
```

*Note: In the serial monitor, you should see the ESP32 connect to Wi-Fi and attempt to initialize micro-ROS. It will keep retrying or waiting until the agent is running.*

## Step 3: Run the micro-ROS Agent

The micro-ROS agent acts as a bridge between the ESP32 and the ROS 2 network. Open a **new terminal** on your Ubuntu machine and run the agent using Docker:

```bash
docker run -it --rm \
  --net=host \
  microros/micro-ros-agent:jazzy \
  udp4 --port 8888 -v6
```

*Once the agent is running, check your PlatformIO Serial Monitor. The ESP32 should output `"micro-ROS initialization complete"` and start publishing counter values.*

## Step 4: Testing & Interacting (ROS 2 Commands)

Open a **new terminal** to interact with the ESP32 using standard ROS 2 commands.

### 4.1 Verify the ROS 2 Environment

Ensure your terminal is properly set up:

```bash
source ~/.bashrc
# Or manually source ROS 2: source /opt/ros/jazzy/setup.bash
```

Check your ROS environment variables:

```bash
printenv | grep ROS
ros2 --help
```

### 4.2 Check Nodes and Topics

Check if the ESP32 node and topics are visible on the network:

```bash
ros2 node list
ros2 topic list
```

**Troubleshooting (If nodes/topics are not detected):**
If you don't see `/esp32_node`, `/esp32/counter`, or `/esp32/led_command`, run the following commands to configure your network settings and restart the ROS 2 daemon:

```bash
source ~/.bashrc
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ros2 daemon stop
ros2 node list
ros2 topic list
```

### 4.3 Test the Publisher (Counter)

To see the live data being published by the ESP32 counter:

```bash
ros2 topic echo /esp32/counter
```
*(Press `Ctrl+C` to stop echoing).*

### 4.4 Test the Subscriber (LED Control)

First, verify the subscriber topic is active and check its info:

```bash
ros2 topic info /esp32/led_command
```

Now, publish a boolean message to turn the ESP32 onboard LED **ON**:

```bash
ros2 topic pub --once /esp32/led_command std_msgs/msg/Bool "{data: true}"
```

Publish a boolean message to turn the ESP32 onboard LED **OFF**:

```bash
ros2 topic pub --once /esp32/led_command std_msgs/msg/Bool "{data: false}"
```

*Watch your physical ESP32 board; the LED (Pin 2) should turn on and off corresponding to these commands, and the Serial Monitor will log the received states.*