# ROS 2 Jazzy 개편 API 개요

이 문서는 개편 overlay(`/opt/ros/jazzy` 위의 `ws`)가 순정 Jazzy에 더하거나 바꾼 것을 사용자 쪽에서 정리한다. 이름은 각 포크의 `jazzy` 브랜치 코드에서 확인했다. 저장소 목록은 [ros2_plus.repos](../ros2_plus.repos)에 있다.

- "Jazzy에 없음"은 순정 Jazzy에 없는 API다. 이 API를 부르는 코드는 개편 overlay가 있어야 빌드되고 실행된다.
- 표시가 없는 항목은 순정에 있는 이름이고, 동작이나 지원 범위만 바뀌었다.
- 기존 공개 구조체 배치와 export 심볼은 바꾸지 않았다. 순정 헤더로 빌드한 바이너리는 overlay 위에서 그대로 돈다.
- 함수 시그니처, 인자, 반환값은 이 문서에 옮겨 적지 않는다. 코드에서 생성한 참조를 본다(아래).

## 생성 참조

rosdoc2(docs.ros.org를 만드는 도구, `rosdoc2==0.2.1`과 doxygen)로 패키지마다 C/C++는 Doxygen, Python은 Sphinx autodoc 참조를 만든다. Python 참조는 패키지를 import하므로 ws를 빌드하고 `install/setup.bash`를 불러온 뒤 `ws`에서 패키지 디렉터리마다 실행한다.

```bash
rosdoc2 build -p src/ros2/rcl/rcl -o docs_build/out -d docs_build/work
```

결과는 `docs_build/out/<패키지>/index.html`이다. 이 문서는 생성 참조가 보여주지 않는 것만 다룬다: 런타임 스위치, 바뀐 동작, CLI 옵션, 파라미터, 설정 키, 주의할 점.

## 1. 런타임 스위치

모두 기본으로 꺼져 있다. 스위치를 모두 끄면 동작은 순정 Jazzy와 같고, 3절의 기본 동작 변경만 적용된다.

| 변수 | 기본 | 켜는 것 | rmw_zenoh_cpp(1등급, 기본) | rmw_cyclonedds_cpp(1등급) |
| --- | --- | --- | --- | --- |
| `ROS_EXECUTOR_CORE=1` | 꺼짐 | rclcpp·rclpy의 `SingleThreadedExecutor`, `MultiThreadedExecutor`(`rclcpp::spin` 포함)를 rcl_executor core의 `WAIT_SET` 정책으로 돌린다. executor를 만들 때 읽는다 | 지원 | 지원 |
| `RCL_INTRA_PROCESS=1` | 꺼짐 | 같은 rcl context 안의 topic, service, action 메시지를 rcl broker가 직렬화 없이 넘긴다. context를 초기화할 때 읽는다 | 지원 | 효과 없음(순정 경로) |
| `RCLPY_MESSAGE_ARRAYS=numpy` | 꺼짐 | rclpy 구독과 `rclpy.serialization.deserialize_message`가 숫자 배열·시퀀스 필드를 읽기 전용 numpy view로 준다. 첫 수신 변환 때 한 번 읽는다 | 지원 | 지원 |
| `ROS_DISABLE_LOANED_MESSAGES=0` | Jazzy 기본은 구독 loan 꺼짐 | 순정 변수다. 구독이 rmw loan을 take한다 | 개편이 loan을 구현했다(SHM 켬, 고정 크기 타입) | 순정 동작 |
| `ZENOH_CONFIG_OVERRIDE='transport/shared_memory/enabled=true'` | SHM 꺼짐 | 순정 rmw_zenoh 변수다. SHM 전송과 rmw_zenoh loan의 전제 | 지원 | 해당 없음 |

broker를 쓰지 않는 엔티티:

- `RCL_INTRA_PROCESS=1`이어도 KEEP_LAST(depth > 0), VOLATILE, deadline·lifespan·liveliness lease 없음, MANUAL_BY_TOPIC 아님, content filter 없음을 모두 만족하는 엔티티만 broker를 쓴다. 나머지는 rmw 경로 그대로다.
- rclcpp에서 `use_intra_process_comms(true)`로 기존 intra-process manager를 고른 엔티티와 `IntraProcessSetting::Disable`로 끈 엔티티는 broker를 쓰지 않는다.
- 다른 context, 다른 프로세스의 구독은 rmw로 받는다. 한 메시지는 같은 구독에 한 번만 도착한다.

## 2. 패키지별 새 API

이 절은 이름과 용도만 적는다. 인자와 반환형은 생성 참조(`tools/build_docs.sh <패키지>`)에 있다.

### 2.1 rcl

`rcl/guard_condition.h`, `rcl/subscription.h`, `rcl/service.h`, `rcl/client.h`, `rcl/event.h`, `rcl/timer.h`에 더했다. 모두 Jazzy에 없다.

| 함수 | 용도 |
| --- | --- |
| `rcl_guard_condition_set_on_trigger_callback` | `rcl_trigger_guard_condition()`이 성공할 때마다 callback을 부른다. 등록 전 trigger는 쌓였다가 등록할 때 전달된다. rmw 안에서 직접 하는 trigger(graph guard condition)는 보고하지 않는다 |
| `rcl_subscription_set_executor_callback`, `rcl_service_set_executor_callback`, `rcl_client_set_executor_callback`, `rcl_event_set_executor_callback` | executor용 readiness callback 칸이다. 사용자가 `rcl_*_set_on_new_*_callback`으로 건 callback과 함께 불리고 서로 덮어쓰지 않는다 |
| `rcl_timer_set_on_schedule_change_callback` | `RCL_ROS_TIME` timer의 다음 호출 시각이 시간 점프나 ROS time 켜기·끄기로 바뀔 때 부른다. on-reset callback은 이때 불리지 않는다 |

`rcl/intra_process.h`(새 헤더, 모두 Jazzy에 없음)는 broker의 언어 바인딩용 API다. rclcpp와 rclpy가 이미 부르므로 응용 코드가 직접 부를 일은 드물다.

| 함수 | 용도 |
| --- | --- |
| `rcl_publish_ipc_owned` | 소유권을 넘기며 발행한다. 어떤 경로로 돌아가도 `owner`를 소비한다 |
| `rcl_publish_ipc_adapted` | type adapter 객체를 발행한다. 같은 `key`로 받는 구독은 변환 없이 객체를 읽고, ROS 메시지가 필요한 쪽이 있을 때만 `fill`이 한 번 돈다 |
| `rcl_publisher_disable_ipc`, `rcl_subscription_disable_ipc` | 엔티티 하나를 broker에서 뺀다 |
| `rcl_publisher_is_ipc_enabled`, `rcl_subscription_is_ipc_enabled` | 엔티티가 broker를 쓰는지 |
| `rcl_take_ipc_message`, `rcl_ipc_message_release` | 복사 없이 take하고, 다 쓴 뒤 놓는다. 엔티티를 없앤 뒤에 놓아도 된다 |
| `rcl_take_ipc_adapted` | 같은 key의 adapted 객체면 `*adapted`, 아니면 `*data`를 채운다 |
| `rcl_subscription_set_serialized_ipc` | generic·raw 구독이 broker 메시지를 직렬화된 바이트로 받게 한다(발행마다 한 번 lazy 직렬화를 공유) |
| `rcl_take_ipc_request`, `rcl_take_ipc_response` | service 요청, client 응답을 복사 없이 take한다 |
| `rcl_borrow_ipc_response`, `rcl_send_ipc_response` | 요청한 client의 broker 버퍼에서 응답을 빌려 채우고 복사 없이 보낸다. 보낸 뒤 응답을 고치지 않는다 |

`rcl/ipc_prototype.h`의 `rcl_ipc_prototype_*`(Jazzy에 없음)는 broker 이전의 실험 API다. 한 쌍, KEEP_LAST(1) 전용이고 일반 publish·take를 가로채지 않는다. 새 코드에서는 쓰지 않는다.

### 2.2 rcl_executor

새 패키지 `rcl_executor`(rcl 저장소, CMake 대상 `rcl_executor::rcl_executor`)다. callback group 의미, timer, 대기, 깨움을 C ABI로 가진 공통 executor core이고, rclcpp `RclExecutor`, rclpy `RclExecutor`, `ROS_EXECUTOR_CORE=1`이 이것을 쓴다. 모두 Jazzy에 없다.

| 분류 | 함수(`rcl_executor/executor.h`) |
| --- | --- |
| 생성·해제 | `rcl_executor_create`, `rcl_executor_create_with_policy`, `rcl_executor_destroy`, `rcl_executor_reset` |
| 설정 | `rcl_executor_set_group_priority`, `rcl_executor_set_order`, `rcl_executor_set_partitioned`, `rcl_executor_set_thread_start` |
| 등록 | `rcl_executor_add_group`, `rcl_executor_remove_group`, `rcl_executor_add`, `rcl_executor_remove`, `rcl_executor_add_source` |
| 알림 | `rcl_executor_notify`, `rcl_executor_post` |
| pull 실행 | `rcl_executor_wait`, `rcl_executor_next`, `rcl_executor_next_excluding`, `rcl_executor_complete` |
| push 실행 | `rcl_executor_spin` |
| 신호 안전 handle | `rcl_executor_get_handle`, `rcl_executor_handle_destroy`, `rcl_executor_wake`, `rcl_executor_interrupt`, `rcl_executor_stop` |

선택 정책(`rcl_executor_selection_policy_t`):

| 값 | 실행 순서 |
| --- | --- |
| `RCL_EXECUTOR_FIFO` | 도착 순 |
| `RCL_EXECUTOR_WAIT_SET` | rclcpp Jazzy의 라운드 순서(timer, subscription, service, client, waitable) |
| `RCL_EXECUTOR_PRIORITY` | 그룹 우선순위가 큰 것부터, 같으면 FIFO |

`rcl_executor/trace.h`는 트레이싱 도구용 앵커(`rcl_executor_trace_*`)다.

### 2.3 rmw, rmw_zenoh_cpp

RMW 구현자용이다. 응용 코드는 부르지 않는다.

| 이름 | 위치 | 용도 |
| --- | --- | --- |
| `rmw_ipc_api_t`, `rmw_get_ipc_api_fn` | `rmw/intra_process.h`(Jazzy에 없음) | broker 메시지 라우팅 확장(같은 context의 수신자를 rmw 전달에서 제외) |
| `rmw_ipc_service_api_t`, `rmw_get_ipc_service_api_fn` | `rmw/intra_process_service.h`(Jazzy에 없음) | service·client 요청과 응답 라우팅 확장 |
| `rmw_ipc_serialized_api_t`, `rmw_get_ipc_serialized_api_fn` | `rmw/intra_process_serialized.h`(Jazzy에 없음) | 원격에서 받은 바이트를 직렬화 구독에 넘기는 확장 |
| `rmw_get_intra_process_api_v1`, `rmw_get_intra_process_service_api_v1`, `rmw_get_intra_process_serialized_api_v1` | `librmw_zenoh_cpp.so` export(Jazzy에 없음) | rcl이 `dlsym`으로 찾는다. 이 심볼이 있는 RMW에서만 broker가 켜진다 |
| `rmw_borrow_loaned_message`, `rmw_take_loaned_message` 등 loan API | rmw_zenoh_cpp(순정 이름) | 순정 rmw_zenoh는 loan을 지원하지 않는다. 개편은 SHM이 켜져 있고 메모리 배치가 CDR과 같은 고정 크기 타입에서 loan을 준다 |

rmw_zenoh loan의 조건과 수명은 rmw_zenoh 저장소의 `docs/loaned_messages.md`에 있다.

### 2.4 rclcpp

모두 Jazzy에 없다.

| API | 용도 |
| --- | --- |
| `rclcpp::experimental::executors::RclExecutor` | rcl_executor core 위의 executor. 생성자는 스레드 수와 정책(기본 FIFO), 또는 `Mode::Shared`·`Mode::Partitioned`와 정책(기본 WAIT_SET)을 받는다. `Partitioned`는 callback group마다 전용 스레드를 두고 Reentrant group을 거부하며 `spin()`만 된다 |
| `RclExecutor::on_thread_start` | 작업 스레드가 시작할 때 부른다(우선순위, CPU 고정 등). 공유 모드의 index 0은 `spin()`을 부른 스레드다 |
| `RclExecutor::add_source`, `notify_source`, `remove_source` | 외부 대기 소스를 group 배타성과 파티션 배치에 맞춰 dispatch한다. 소스용 스레드나 polling이 없다 |
| `RclExecutor::set_group_priority` | `RCL_EXECUTOR_PRIORITY` 정책의 group 우선순위 |
| `Node::declare_parameters_atomically`, `node_interfaces::NodeParameters::declare_parameters_atomically` | 여러 파라미터를 전부 또는 하나도 선언하지 않고, `/parameter_events`에 이벤트 하나만 낸다. descriptor를 함께 주는 overload가 있다 |
| `NodeOptions::time_source` | 다른 노드의 TimeSource를 공유해 프로세스에 `/clock` 구독 하나만 둔다 |
| `NodeTimeSource::attachClock`, `detachClock` | TimeSource가 다른 노드의 clock도 움직이게 한다 |
| `ServiceBase::take_ipc_request`, `borrow_ipc_response`, `send_ipc_response`, `ClientBase::take_ipc_response` | executor가 broker service 메시지를 복사 없이 주고받는 데 쓴다. 응용 코드는 부르지 않는다 |
| `TypeAdapter<...>::convert_to_custom(std::shared_ptr<const ros_message_type>)`(선택) | 특수화가 이것을 주면 const callback 구독이 ROS 메시지를 복사하지 않고 참조하는 custom 객체를 받는다 |

TimeSource 공유:

```cpp
auto first = std::make_shared<rclcpp::Node>("first");
auto second = std::make_shared<rclcpp::Node>(
  "second", rclcpp::NodeOptions().time_source(first->get_node_time_source_interface()));
```

TimeSource를 만든 노드의 `use_sim_time`, clock QoS, `use_clock_thread`가 공유하는 모든 노드에 적용된다. 공유하는 노드는 `use_sim_time`을 선언하지 않는다.

파라미터 묶음 선언:

```cpp
auto values = node->declare_parameters_atomically(
  "camera", {rclcpp::Parameter("width", 1920), rclcpp::Parameter("height", 1080)});
```

### 2.5 rclcpp_lifecycle

`LifecycleNode::declare_parameters_atomically`(Jazzy에 없음)는 `Node`와 같다. `LifecycleNode::get_node_time_source_interface()`의 결과도 `NodeOptions::time_source()`에 줄 수 있다.

### 2.6 rclpy

| API | 용도 | 표시 |
| --- | --- | --- |
| `Executor.spin_some` | 지금 준비된 작업을 호출 스레드에서 엔티티마다 최대 한 번 실행하고 돌아온다(`rclcpp::Executor::spin_some`과 같은 계약). `max_duration_sec`가 0이면 시간 제한이 없다 | Jazzy에 없음 |
| `rclpy.experimental.RclExecutor` | rcl_executor core 위의 executor. 정책 기본값은 FIFO, `partitioned=True`면 WAIT_SET. 파티션 모드는 `spin()`만 되고 Reentrant group을 거부한다 | Jazzy에 없음 |
| `RclExecutor.on_thread_start`, `set_group_priority`, `post` | 스레드 시작 hook(작업 index와 group 또는 None), group 우선순위(큰 값 먼저), 작업 게시 | Jazzy에 없음 |
| `rclpy.experimental.SelectionPolicy` | `FIFO`, `WAIT_SET`, `PRIORITY` | Jazzy에 없음 |
| `Publisher.borrow_loaned_message`, `Publisher.can_loan_messages` | 미들웨어가 빌려주면 그 메모리의 메시지(`LoanedMessage`)를 준다. 숫자 배열은 쓰기 가능한 numpy view다. 빌려주지 않으면 보통의 새 메시지를 준다 | Jazzy에 없음 |
| `Publisher.publish` | `LoanedMessage`를 받으면 loan을 그대로 발행한다. view가 메시지 밖에서 아직 참조되면 사본을 발행한다 | 인자 형식 추가 |
| `rclpy.publisher.LoanedMessage` | `.msg`로 채운다. `with` 블록을 발행 없이 나가면 loan을 돌려준다 | Jazzy에 없음 |
| `Subscription.can_loan_messages` | 받은 메시지가 미들웨어 loan인지. `RCLPY_MESSAGE_ARRAYS=numpy`면 마지막 view가 사라질 때 loan을 돌려준다 | Jazzy에 없음 |
| `Node(..., use_clock_thread=False)`, `TimeSource(..., use_clock_thread=False)` | `use_sim_time`일 때 `/clock`을 전용 스레드에서 받아 callback이 도는 동안에도 ROS time이 진행한다 | Jazzy에 없음 |
| `Context.init(..., context_lease=None)` | C++ 컨테이너가 가진 rcl context를 빌려 쓴다(`component_container_mixed`가 쓴다). 종료 권한은 컨테이너에 있다 | Jazzy에 없음 |
| `Future.add_done_callback(callback, *, unique=False)` | `unique=True`면 이미 등록된 같은 callback을 다시 넣지 않는다 | 인자 추가 |
| `rclpy.type_adapter`(`TypeAdapter`, `register_type_adapter`, `create_publisher`, `create_subscription`, `AdaptedPublisher`) | Python type adapter 시제품. 경계에서 한 번 변환한다. 상세는 rclpy 저장소의 `rclpy/docs/type_adapters.md` | Jazzy에 없음 |

loan으로 발행하기(rmw_zenoh_cpp, SHM 켬, 고정 크기 타입):

```python
pub = node.create_publisher(PlainPayload, 'payload', 10)
loaned = pub.borrow_loaned_message()
loaned.msg.data[:] = frame      # 쓰기 가능한 numpy view
pub.publish(loaned)             # 이후 loaned.msg는 쓸 수 없다
```

수신 view(`RCLPY_MESSAGE_ARRAYS=numpy`):

```python
def callback(msg):
    pixels = msg.data             # 읽기 전용 numpy view
    mine = msg.data.copy()        # 고칠 때는 복사한다
```

view는 받은 C 메시지 전체를 붙잡는다. 작은 조각만 오래 둘 때는 복사한다. 생성자와 setter는 기존 컨테이너를 그대로 쓴다.

### 2.7 rclpy_components

새 패키지(rclpy 저장소)다. 사용법은 5절에 있다. 모두 Jazzy에 없다.

| 이름 | 종류 | 용도 |
| --- | --- | --- |
| `component_container` | 실행 파일 | Python 노드 컨테이너(`SingleThreadedExecutor`) |
| `component_container_mt` | 실행 파일 | Python 노드 컨테이너(`MultiThreadedExecutor`) |
| `component_container_mixed` | 실행 파일 | rclcpp component와 rclpy 노드를 한 rcl context에 둔다 |
| `rclpy_components.component_manager.ComponentManager` | 클래스 | `~/_container/load_node`, `unload_node`, `list_nodes` service를 제공하는 노드 |
| `find_component`, `load_component`, `ComponentError` | 함수, 예외 | plugin 이름으로 클래스를 찾고 만든다 |
| `rclpy_components` | entry point group | 클래스를 이름으로 등록한다 |

### 2.8 생성 메시지(rosidl_generator_py)

overlay의 `rosidl_generator_py`로 다시 생성한 메시지 패키지에만 적용된다.

| 대상 | 내용 | 표시 |
| --- | --- | --- |
| `byte[]`(`sequence<octet>`, bounded 포함) 필드 | 값이 `bytes`이고 기본값은 `b''`이다. 1바이트 `bytes`의 list, `bytearray`, `memoryview`, `array.array`, numpy 배열을 대입하면 `bytes`로 바꿔 저장한다 | 동작 변경 |
| 숫자 시퀀스 setter | native-endian 1차원 numpy 배열(dtype 일치)을 원소 순회 없이 한 번 복사한다. dtype이나 byte order가 다르면 list와 같은 변환과 검사를 거친다. 2차원 이상은 `TypeError` | 동작 변경(빨라짐) |
| 수신 numpy view | `RCLPY_MESSAGE_ARRAYS=numpy`에서 숫자 배열·시퀀스가 읽기 전용 view다. `byte[]`는 `bytes`, 문자열·메시지 시퀀스는 기존 컨테이너다 | Jazzy에 없음 |
| publisher loan view | 쓰기 가능한 owner의 view는 쓰기 가능하다. 다시 생성하지 않은 패키지는 loan을 읽기 전용 view로 준다 | Jazzy에 없음 |

상세는 rosidl_python 저장소의 `rosidl_generator_py/docs/message_arrays.md`에 있다.

### 2.9 rosidl_runtime_py

| 대상 | 내용 |
| --- | --- |
| `message_to_ordereddict`, `message_to_yaml`, `message_to_csv` | `bytes`가 된 `byte[]` 필드를 순정과 같은 1바이트 list 형식으로 출력한다. `ros2 topic echo` 출력이 순정과 같다 |
| `set_message_fields` | `byte[]` 필드에 위 형식의 list를 받는다 |

### 2.10 rosbag2

| API | 용도 | 표시 |
| --- | --- | --- |
| `ros2 bag record --topic-throttle-frequency TOPIC=HZ [TOPIC=HZ ...]` | 고른 topic의 녹화 주기를 제한한다. 첫 메시지를 남기고 이후 수신 시각이 한 주기 이상 떨어진 것만 쓴다. `--use-sim-time`이면 sim time을 쓴다 | Jazzy에 없음 |
| 파라미터 `record.topic_throttle_frequency`(string 배열, 예 `/imu=10`) | composable recorder에서 같은 기능 | Jazzy에 없음 |
| `rosbag2_py.RecordOptions.topic_throttle_frequencies: Dict[str, float]` | Python에서 같은 기능 | Jazzy에 없음 |
| `ros2 bag convert` 출력 설정의 `topic_message_ranges` | topic마다 0부터 세는 닫힌 구간 `{start, end}`의 메시지만 쓴다. 범위 밖 index, 없는 topic, 뒤집힌 구간은 출력 전에 거부한다 | Jazzy에 없음 |
| `rosbag2_transport::TopicMessageRanges`와 이를 받는 `bag_rewrite` overload | C++에서 같은 기능(출력마다 map 하나) | Jazzy에 없음 |
| `ReadersManager::get_all_message_definitions` | 모든 reader의 메시지 정의 | Jazzy에 없음 |
| MCAP storage 옵션 `chunkByTopic: true`, `chunkByTopicMaxDelayMs`(기본 1000) | topic마다 chunk를 따로 써서 일부 topic만 읽을 때 그 chunk만 읽고 푼다. 파일 안 순서가 log time 순이 아니게 된다 | Jazzy에 없음 |

```bash
ros2 bag record -a --topic-throttle-frequency /imu=10 /camera/image_raw=2
ros2 bag record -a -s mcap --storage-config-file chunk_by_topic.yaml   # chunkByTopic: true
```

```yaml
output_bags:
- uri: selected_samples
  storage_id: mcap
  all_topics: true
  topic_message_ranges:
    /camera/image_raw: {start: 10, end: 42}
```

### 2.11 launch, launch_ros

| API | 용도 | 표시 |
| --- | --- | --- |
| `ros2 launch <package> <file> --dump-params` | 프로세스를 띄우지 않고 launch 파일을 평가해 노드별 최종 파라미터를 params 파일 YAML로 출력한다. composable node도 포함한다 | Jazzy에 없음 |
| `ros2launch.api.dump_params_of_a_launch_file` | 위의 Python API. 성공하면 0 | Jazzy에 없음 |
| `launch_ros.descriptions.CombinedParameterFiles` | 여러 파라미터 파일을 rcl이 적용하는 순서(뒤 파일 우선)로 합쳐 한 파일로 넘긴다 | Jazzy에 없음 |
| XML `<param><file path="a.yaml"/><file path="b.yaml"/></param>`, YAML `param: [{file: [{path: a.yaml}, {path: b.yaml}]}]` | frontend에서 같은 기능 | Jazzy에 없음 |
| `launch.utilities.select_entry_points` | 설치된 entry point를 프로세스마다 한 번만 읽고 group을 고른다 | Jazzy에 없음 |
| `launch_ros.utilities`: `DumpParamsCollector`, `DumpParamsError`, `attach_dump_params_collector`, `get_dump_params_collector`, `is_dump_params_mode` | `--dump-params`를 지원하려는 launch 확장용 | Jazzy에 없음 |

### 2.12 ros2cli

새 명령 옵션은 없다. 동작 변경은 3절에 있다. `ros2topic.api`에 `spin_until_shutdown`(EventsExecutor로 spin), `sensor_qos_matching_publishers`(발행자가 모두 reliable이면 reliable인 sensor data profile)를 더했다(Jazzy에 없음).

### 2.13 image_transport

`image_transport/image_transport.hpp`에 더했다. 모두 Jazzy에 없다.

| API | 용도 |
| --- | --- |
| `image_transport::TypeAdaptedPublisher<AdapterT>` | raw transport는 adapted 타입 그대로 발행해 같은 프로세스의 adapted 구독이 변환 없이 받는다. 다른 transport와 프로세스 밖 raw 구독은 `sensor_msgs::msg::Image` 변환 하나를 공유한다 |
| `image_transport::TypeAdaptedCameraPublisher<AdapterT>` | 위에 `CameraInfo`를 더한 판 |
| `create_type_adapted_publisher<AdapterT>`, `create_type_adapted_camera_publisher<AdapterT>` | 위의 free function |
| `create_type_adapted_subscription<AdapterT>` | raw transport를 adapted callback으로 구독한다 |

`AdapterT`의 ROS 타입은 `sensor_msgs::msg::Image`여야 한다. `<topic>.enable_pub_plugins` 파라미터는 `Publisher`와 같이 동작한다.

### 2.14 image_transport_plugins(depthz)

새 transport `depthz`(패키지 `depthz_image_transport`, Jazzy에 없음)다. `32FC1`, `16UC1` depth 영상을 압축하고 기본은 비트 단위 무손실이다.

| 파라미터 | 기본 | 뜻 |
| --- | --- | --- |
| `<base_topic>.depthz.quantization` | `0.0` | 32FC1 양자화 간격(mm). 0이면 무손실, 16UC1에는 쓰지 않는다 |
| `<base_topic>.depthz.zstd_level` | `1` | zstd 단계(1~3) |

```bash
ros2 run my_pkg my_depth_consumer --ros-args -p image_transport:=depthz
```

상세는 image_transport_plugins 저장소의 `depthz_image_transport/README.md`에 있다.

### 2.15 cv_bridge

| API | 용도 | 표시 |
| --- | --- | --- |
| `cv_bridge::cvtColorToImageMsg` | 색 변환 결과를 새 메시지 버퍼에 바로 쓴다 | Jazzy에 없음 |
| `ROSCvMatContainer` 이동 생성자와 이동 대입 | 영상을 복사하지 않고 넘긴다 | Jazzy에 없음 |
| `ROSCvMatContainer` type adapter의 `convert_to_custom(std::shared_ptr<const Image>)` | 받은 메시지를 참조하는 container를 만든다(rclcpp의 shared 변환 hook) | Jazzy에 없음 |
| `cv_bridge::ROSCvGpuMatContainer`와 그 `rclcpp::TypeAdapter`(`cv_bridge/cv_gpu_mat_sensor_msgs_image_type_adapter.hpp`) | `cv::cuda::GpuMat` type adapter. CUDA로 빌드한 OpenCV에서만 설치된다(CMake `CV_BRIDGE_ENABLE_CUDA`, 내보내는 변수 `cv_bridge_ENABLE_CUDA`) | Jazzy에 없음 |
| Python `CvBridge.imgmsg_to_cv2_view` | 메시지 버퍼를 그대로 가리키는 numpy view. encoding 변환과 byte order 변환을 하지 않는다 | Jazzy에 없음 |

### 2.16 pcl_conversions

| API | 용도 | 표시 |
| --- | --- | --- |
| `pcl_conversions/pcl_type_adapter.hpp`: `rclcpp::TypeAdapter` 특수화 `pcl::PointCloud<PointT>` ↔ `PointCloud2`, `pcl::PCLPointCloud2` ↔ `PointCloud2`, `pcl::PCLImage` ↔ `Image`, `pcl::PointIndices` ↔ `pcl_msgs::msg::PointIndices` | PCL 타입을 직접 발행·구독한다. 같은 프로세스의 같은 타입 구독은 변환 없이 받는다 | Jazzy에 없음 |
| `pcl_conversions::getXYZMatrixXfMap`(`pcl_conversions/point_cloud2_view.hpp`) | XYZ를 복사 없이 Eigen map으로 읽는다. native-endian 연속 FLOAT32 XYZ, 빈틈없는 행이 필요하다 | Jazzy에 없음 |

```cpp
#include "pcl_conversions/pcl_type_adapter.hpp"
auto pub = node->create_publisher<
  rclcpp::adapt_type<pcl::PointCloud<pcl::PointXYZ>>::as<sensor_msgs::msg::PointCloud2>>(
  "points", 10);
```

### 2.17 ros2_numpy

`ros2_numpy.point_cloud2.get_xyz_points_view`(Jazzy에 없음)는 dtype과 stride를 유지한 XYZ view를 준다.

### 2.18 rviz

| 대상 | 내용 | 표시 |
| --- | --- | --- |
| PointCloud2 display의 Style `Depth Fade Points` | 깊이에 따라 흐려지는 점을 GPU에서 cloud 바이트로 그린다 | Jazzy에 없음 |
| PointCloud2 display의 `Size Field`와 하위 `Min Scale`, `Max Scale`, `Autocompute Value Bounds`, `Min Value`, `Max Value` | 필드 값으로 점 크기를 바꾼다. GPU로 그릴 때(Points, Squares, Flat Squares, Spheres, Depth Fade Points)만 적용된다 | Jazzy에 없음 |
| Image display의 `Linear input` | Bayer 영상을 linear light로 보고 sRGB로 표시한다. Bayer 영상을 받을 때만 보인다 | Jazzy에 없음 |

## 3. 켜지 않아도 바뀌는 동작

| 대상 | 바뀐 것 | 사용자가 볼 수 있는 것 |
| --- | --- | --- |
| rclcpp `MultiThreadedExecutor` | 실행 중인 mutually exclusive group에 대기 작업이 있어도 다른 스레드가 깨어 헛돌지 않는다. callback마다 guard condition을 깨우지 않고 wait에서 빠진 group을 놓을 때만 깨운다 | CPU 사용률 감소(20 ms callback 예에서 81~84% -> 2~4%), `rcl_wait` 호출 수 절반 |
| rclcpp `experimental::executors::EventsExecutor` | 늦은 timer가 이벤트를 여러 개 쌓지 않는다. 소비되지 않은 이벤트가 있으면 새 이벤트를 넣지 않는다 | 늦은 timer가 연달아 여러 번 실행되지 않는다 |
| rclcpp `executors::EventsCBGExecutor` | KEEP_LAST 구독의 대기 이벤트를 depth까지만 둔다 | 막힌 구독에서 메모리가 무한히 늘지 않는다 |
| rclcpp callback group | 엔티티 추가가 상각 O(1)이다 | 엔티티 수천 개를 만드는 시간 감소 |
| rclcpp 구독 loan | 마지막 `shared_ptr`가 사라질 때 loan을 돌려준다 | callback 뒤에도 loan 메시지를 보관할 수 있다. 순정 헤더로 빌드한 바이너리는 순정처럼 callback 직후 돌려준다 |
| rclcpp, rclpy guard condition | rcl guard condition에 on-trigger callback이 생겼다. rclpy `EventsExecutor`가 guard condition을 받는다 | rclpy EventsExecutor에서 guard condition을 쓰는 코드가 동작한다 |
| rclpy executor | SIGINT로 context가 꺼지는 경쟁에서 `RCLError` 대신 `ExternalShutdownException`으로 끝난다. rolling의 task·future 수정(예외 전파, wake callback 누적)을 옮겼다. `EventsExecutor`가 `(msg, info)` callback에 두 인자를 넘긴다 | Ctrl-C 종료가 일정하다. `spin_until_future_complete` 반복 호출이 callback을 쌓지 않는다 |
| rclpy sim time | `/clock` 구독이 자기 callback group을 쓴다 | `MultiThreadedExecutor`에서 callback이 도는 동안에도 ROS time이 진행한다 |
| rclpy take | 직전 take가 100 us 이상 걸린 구독은 C 단계 take 동안 GIL을 놓는다 | 큰 메시지를 받는 동안 다른 Python 스레드가 덜 막힌다 |
| 생성 메시지 `byte[]` | `bytes`로 바뀌었다(2.8) | `msg.data`가 list가 아니라 `bytes`다. list 대입은 계속 된다. `ros2 topic echo` 형식은 순정과 같다 |
| rmw_zenoh_cpp | SHM을 켜면 고정 크기 타입에 loan을 준다. 엔티티 삭제 중 교착(rmw_zenoh#994)을 고쳤다. 조각 payload를 0으로 채우지 않고 모은다 | `borrow_loaned_message()`가 SHM 메모리를 준다. rosbag2 player처럼 `can_loan_messages()`를 보는 코드가 loan으로 발행한다 |
| rosidl_typesupport_fastrtps | 시퀀스를 0으로 채운 뒤 덮어쓰지 않고, 중첩 plain 시퀀스는 검사 뒤 한 번에 복사한다 | 큰 메시지 역직렬화 시간 감소(다시 생성한 메시지 패키지) |
| rmw_cyclonedds | KEEP_ALL 구독에 callback 등록 전 도착한 메시지 수를 줄이지 않는다 | events 계열 executor가 등록 전 메시지를 놓치지 않는다 |
| `ros2 topic hz`, `bw`, `delay` | 세 명령 모두 EventsExecutor로 spin하고 SIGINT로 끝날 때 오류 종료 코드를 내지 않는다. `hz`와 `bw`는 발행자가 모두 reliable이면 reliable로 구독한다 | 큰 메시지(8 MiB 등)에서도 값이 나온다. 1 kHz CPU 36.8% -> 8.6%. 5 kHz에서는 메시지 0.2~0.4%를 놓쳐 약간 낮게 보고한다 |
| `ros2` 명령 | 시작할 때 fd table을 미리 키우고 entry point를 명령마다 한 번 읽는다 | `ros2 launch`의 프로세스 spawn이 빨라진다 |
| launch | substitution을 직접 짠 파서로 읽고 lark는 오류 보고에만 쓴다. launch 확장은 모르는 이름이 나올 때만 하나씩 로드한다. entry point는 프로세스마다 한 번 읽는다. 이벤트 handler를 색인하고 일반 화면 출력은 묶어서 낸다. `find-pkg-share` 결과를 캐시한다 | launch 평가와 시작 시간 감소. launch 도중 설치한 패키지의 entry point는 보이지 않는다. import만으로 부작용을 내는 확장은 그 이름이 나올 때까지 로드되지 않는다 |
| rosbag2 녹화 | 설치되지 않은 타입의 topic은 발행 노드의 `get_type_description` service로 정의를 받아 녹화한다(rmw_zenoh_cpp에서만). 분할마다 메타데이터가 커지지 않는다. 비압축 MCAP 녹화에서 payload 복사가 없다 | `ros2 bag record -a`가 그런 topic을 건너뛰지 않는다 |
| rosbag2 재생 | 설치되지 않은 타입은 bag에 저장된 정의로 발행한다. MCAP 읽기와 재생에서 payload 복사가 없다 | 타입 패키지 없이 재생된다. 재생 CPU 감소 |
| rosbag2 `bag_size`, `wstring` | `bag_size`를 bag 폴더 기준으로 storage를 닫은 뒤 잰다. `wstring` 필드가 있는 타입의 정의를 `.msg`로 저장한다 | 다른 cwd에서 녹화해도 크기가 맞다 |
| rviz | ROS 대기와 take·역직렬화를 `rviz_ros` 스레드에서 하고 callback만 GUI 스레드에서 실행한다(구독마다 KEEP_LAST depth까지 보관). PointCloud2를 GLSL 1.30 shader로 그린다. 16UC1·32FC1 정규화와 Bayer 변환을 shader에서 한다. map은 텍스처를 유지하고 바뀐 칸만 올린다. 크기가 맞지 않는 map update를 거부한다. SIGINT로 정상 종료한다 | 큰 영상·점군에서 표시 속도와 GUI 반응성이 오른다. Boxes, Tiles, RGBF32, 외부 transformer, float32가 아닌 xyz는 CPU 경로로 그린다. Mesa llvmpipe에서 intensity 색이 최대 1 LSB 다를 수 있다 |
| image_view | 새 frame마다 창 스레드를 깨운다 | 60 Hz 표시가 8 Hz로 떨어지지 않는다 |
| cv_bridge | Python byte swap이 numpy 2에서 동작한다. compressed 영상 변환의 `desired_encoding` 오류를 고쳤다 | numpy 2에서 big-endian 영상 변환이 된다 |
| tf2_sensor_msgs, ros2_numpy | 추가 필드가 있는 점군 변환, 영상·점군 변환에서 복사를 줄였다 | 결과는 같고 빨라진다 |

## 4. 주의할 점

- loan은 작은 메시지에서 더 느리다(PoseWithCovariance 발행 1.6 -> 4.8 us). 큰 고정 크기 메시지에만 쓴다. rmw_zenoh loan은 문자열이나 시퀀스가 있는 타입(`Image`, `PointCloud2` 포함)을 빌려주지 않는다.
- rmw_zenoh_cpp는 프로세스에서 처음 borrow할 때 loan pool(`transport/shared_memory/transport_optimization/pool_size`, 기본 48 MiB)을 만든다. 첫 borrow가 약 24 ms 늦다. rosbag2 player는 재생 전에 publisher마다 loan을 한 번 받아 두므로 첫 재생 메시지는 늦지 않는다. loan을 쓰는 다른 노드는 첫 발행이 늦는다.
- 구독이 받은 loan은 발행자와 다른 구독자가 함께 쓰는 SHM이다. 쓰기 가능하게 매핑되지만 고치지 않는다.
- 메시지 패키지는 overlay의 생성기와 typesupport로 다시 빌드해야 한다. 그래야 `byte[]`의 `bytes`, 쓰기 가능한 loan view, numpy view, 역직렬화 개선이 적용된다. 처음 빌드한 뒤 `grep -l /opt/ros/jazzy/share/rosidl_generator_py ws/build/*/CMakeCache.txt`가 비어 있는지 확인하고, 걸리는 패키지는 `--cmake-clean-cache`로 다시 빌드한다.
- broker를 쓰면(rmw_zenoh_cpp, `RCL_INTRA_PROCESS=1`) 같은 context에서 받은 메시지의 `from_intra_process`가 `true`다. 이 값으로 rclcpp intra-process manager를 판별하는 코드는 결과가 달라진다.
- broker 구독은 loan을 보고하지 않는다(`can_loan_messages`가 false). rclcpp에서 수정 가능한 `std::shared_ptr<T>`를 받는 callback은 broker 메시지의 사본을 받는다.
- `ROS_EXECUTOR_CORE=1`이면 core가 guard condition의 on-trigger callback과 timer의 on-reset·schedule-change callback 칸을 쓴다. 이 칸에 사용자 callback을 따로 걸면 executor에 있는 동안 덮인다. 구독·service·client·QoS 이벤트의 callback은 2.1의 executor 칸을 써서 함께 불린다.
- `RCLPY_MESSAGE_ARRAYS=numpy`의 view는 C 메시지 전체를 붙잡는다. 들어온 버퍼를 제자리에서 바꾸는 코드(예: 다른 byte order 점군을 바꾸는 `sensor_msgs_py.point_cloud2.read_points`)는 먼저 복사한다. service와 action은 계속 복사해서 받는다.
- 이 문서의 "Jazzy에 없음" API를 쓰면 코드가 개편 overlay에 의존한다. 순정 `/opt/ros/jazzy`만으로는 빌드되지 않고, overlay로 빌드한 바이너리는 순정 위에서 심볼을 찾지 못한다.
- 반대로 순정 헤더로 빌드한 기존 바이너리는 다시 빌드하지 않아도 overlay 위에서 돈다(ABI 유지). 이런 바이너리는 순정 loan 수명 규칙을 따른다.
- numpy 2 venv(`tools/env_numpy2.sh`)를 쓰면 cv_bridge를 numpy 2 헤더로 빌드해야 한다(README 참고). numpy 1.26 헤더로 빌드한 cv_bridge는 numpy 2에서 import할 때 죽는다.
- rmw_zenoh_cpp는 순정에도 deadline·liveliness·incompatible QoS 이벤트가 없고 모든 QoS 조합을 호환으로 본다. 개편이 이 차이를 바꾸지 않았다.

## 5. Python composition

`rclpy_components`는 Python 노드용 `component_container`, `component_container_mt`와 C++·Python 혼합용 `component_container_mixed`를 제공한다. 세 컨테이너 모두 rclcpp_components와 같은 `~/_container/load_node`, `unload_node`, `list_nodes` service를 쓰므로 `ros2 component load`, `list`, `unload`가 그대로 동작한다.

혼합 컨테이너는 rclcpp `ComponentManager`를 상속한다. rclcpp_components ament index에 등록된 plugin은 C++로 불러오고, 그 밖의 plugin은 Python으로 불러온다. Python 노드는 컨테이너의 rcl context를 빌려 rclpy 기본 context로 쓰고, 별도 스레드의 rclpy `SingleThreadedExecutor`가 돌린다. 같은 context이므로 `RCL_INTRA_PROCESS=1`과 rmw_zenoh_cpp에서 C++와 Python 노드 사이 메시지가 broker를 지난다.

```bash
RCL_INTRA_PROCESS=1 ros2 run rclpy_components component_container_mixed
```

다른 터미널에서 같은 ROS 환경과 domain으로 노드를 불러온다.

```bash
ros2 component load /ComponentManager composition composition::Talker
ros2 component load /ComponentManager my_nodes 'my_nodes.listener:Listener'
ros2 component list
```

plugin 이름 규칙:

- `module:Class` 형식이면 module을 import해 클래스를 찾는다.
- 아니면 entry point group `rclpy_components`에서 이름이 `<plugin>` 또는 `<package>::<plugin>`인 항목을 찾는다.

```python
# setup.py
entry_points={
    'rclpy_components': ['my_nodes::Listener = my_nodes.listener:Listener'],
},
```

노드 클래스 규칙:

- `rclpy.node.Node`를 상속한다.
- 생성자는 키워드 인자 `context`, `cli_args`, `use_global_arguments`, `parameter_overrides`를 받아 `Node` 생성자에 넘긴다. 노드 이름·namespace·remap은 `cli_args`로 온다.
- load 요청의 extra argument `forward_global_arguments`(bool)가 `use_global_arguments`가 된다.

```python
from rclpy.node import Node
from std_msgs.msg import String


class Listener(Node):

    def __init__(self, **kwargs):
        super().__init__('listener', **kwargs)
        self.create_subscription(String, 'chatter', self.on_message, 10)

    def on_message(self, msg):
        self.get_logger().info(msg.data)
```

launch에서는 기존 `launch_ros`의 `ComposableNodeContainer`와 `ComposableNode`에 같은 plugin 이름을 쓴다.

```python
ComposableNodeContainer(
    name='mixed', namespace='', package='rclpy_components',
    executable='component_container_mixed',
    composable_node_descriptions=[
        ComposableNode(package='composition', plugin='composition::Talker'),
        ComposableNode(package='my_nodes', plugin='my_nodes.listener:Listener'),
    ])
```

한계:

- `ros2 component types`는 Python component를 보여주지 않는다.
- 생성자가 위 키워드 인자를 받지 않는 클래스(예: `demo_nodes_py`의 `Talker`)는 불러올 수 없다.
- 다중 스레드 혼합 컨테이너는 없다. 혼합 컨테이너의 C++ 쪽과 Python 쪽은 각각 `SingleThreadedExecutor` 하나로 돈다.
- 불러온 Python 노드의 `destroy_node`가 예외를 내면 컨테이너는 그 오류를 로그로 남기고 종료를 계속한다.
