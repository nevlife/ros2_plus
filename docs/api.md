# ROS 2 Jazzy 개편 API 개요

이 문서는 개편 overlay(`/opt/ros/jazzy` 위의 `ws`)가 원본 Jazzy에 더하거나 바꾼 것을 사용자 쪽에서 정리한다. 이름은 각 포크의 `jazzy` 브랜치 코드에서 확인했다. 저장소 목록은 [ros2_plus.repos](../ros2_plus.repos)에 있다.

- "Jazzy에 없음"은 원본 Jazzy에 없는 API다. 이 API를 부르는 코드는 개편 overlay가 있어야 빌드되고 실행된다.
- 표시가 없는 항목은 원본에 있는 이름이고, 동작이나 지원 범위만 바뀌었다.
- 기존 공개 구조체 배치와 export 심볼은 바꾸지 않았다. 원본 헤더로 빌드한 바이너리는 overlay 위에서 그대로 돈다.
- 함수 시그니처, 인자, 반환값은 이 문서에 옮겨 적지 않는다. 코드에서 생성한 참조를 본다(아래).

## 생성 참조

rosdoc2(docs.ros.org를 만드는 도구, `rosdoc2==0.2.1`과 doxygen)로 패키지마다 C/C++는 Doxygen, Python은 Sphinx autodoc 참조를 만든다. Python 참조는 패키지를 import하므로 ws를 빌드하고 `install/setup.bash`를 불러온 뒤 `ws`에서 패키지 디렉터리마다 실행한다.

```bash
rosdoc2 build -p src/ros2/rcl/rcl -o docs_build/out -d docs_build/work
```

결과는 `docs_build/out/<패키지>/index.html`이다. 이 문서는 생성 참조가 보여주지 않는 것만 다룬다: 런타임 스위치, 바뀐 동작, CLI 옵션, 파라미터, 설정 키, 주의할 점.

## 1. 런타임 스위치

모두 기본으로 꺼져 있다. 스위치를 모두 끄면 동작은 원본 Jazzy와 같고, 3절의 기본 동작 변경만 적용된다.

| 변수 | 기본 | 켜는 것 | rmw_zenoh_cpp(1등급, 기본) | rmw_cyclonedds_cpp(1등급) |
| --- | --- | --- | --- | --- |
| `ROS_EXECUTOR_CORE=1` | 꺼짐 | rclcpp·rclpy의 `SingleThreadedExecutor`, `MultiThreadedExecutor`(`rclcpp::spin` 포함)를 rcl_executor core로 돌린다. 실행 순서는 원본 rclcpp wait set과 같다. executor를 만들 때 읽는다 | 지원 | 지원 |

## 2. 패키지별 새 API

이 절은 이름과 용도만 적는다. 인자와 반환형은 위의 생성 참조에 있다.

### 2.1 rcl

`rcl/guard_condition.h`, `rcl/subscription.h`, `rcl/service.h`, `rcl/client.h`, `rcl/event.h`, `rcl/timer.h`에 더했다. 모두 Jazzy에 없다.

| 함수 | 용도 |
| --- | --- |
| `rcl_guard_condition_set_on_trigger_callback` | `rcl_trigger_guard_condition()`이 성공할 때마다 callback을 부른다. 등록 전 trigger는 쌓였다가 등록할 때 전달된다. rmw 안에서 직접 하는 trigger(graph guard condition)는 보고하지 않는다 |
| `rcl_subscription_set_executor_callback`, `rcl_service_set_executor_callback`, `rcl_client_set_executor_callback`, `rcl_event_set_executor_callback` | executor용 readiness callback 칸이다. 사용자가 `rcl_*_set_on_new_*_callback`으로 건 callback과 함께 불리고 서로 덮어쓰지 않는다 |
| `rcl_timer_set_on_schedule_change_callback` | `RCL_ROS_TIME` timer의 다음 호출 시각이 시간 점프나 ROS time 켜기·끄기로 바뀔 때 부른다. on-reset callback은 이때 불리지 않는다 |

### 2.2 rcl_executor

새 패키지 `rcl_executor`(rcl 저장소, CMake 대상 `rcl_executor::rcl_executor`)다. callback group 의미, timer, 대기, 깨움을 C ABI로 가진 공통 executor core이고, `ROS_EXECUTOR_CORE=1`일 때 rclcpp와 rclpy의 `SingleThreadedExecutor`, `MultiThreadedExecutor`가 이것을 쓴다. 모두 Jazzy에 없다.

| 분류 | 함수(`rcl_executor/executor.h`) |
| --- | --- |
| 생성·해제 | `rcl_executor_create`, `rcl_executor_destroy`, `rcl_executor_reset` |
| 설정 | `rcl_executor_set_order` |
| 등록 | `rcl_executor_add_group`, `rcl_executor_remove_group`, `rcl_executor_add`, `rcl_executor_remove` |
| 알림 | `rcl_executor_notify` |
| pull 실행 | `rcl_executor_wait`, `rcl_executor_next`, `rcl_executor_next_excluding`, `rcl_executor_complete` |
| 신호 안전 handle | `rcl_executor_get_handle`, `rcl_executor_handle_destroy`, `rcl_executor_wake`, `rcl_executor_interrupt`, `rcl_executor_stop` |

실행 순서는 rclcpp Jazzy wait set의 라운드 순서(timer, subscription, service, client, waitable)를 따른다. 한 라운드에서 엔티티마다 한 번만 꺼내고, 라운드 도중 준비된 것은 다음 라운드로 넘긴다.

등록한 뒤에는 `notify`, `wait`, `next`, `complete`가 메모리를 할당하지 않는다. 오류는 예외 없이 반환 코드로 알린다. timer의 rcl callback은 executor 잠금 밖에서 불려 executor 함수를 다시 불러도 된다. 지울 수 없는 readiness callback이 남으면 `rcl_executor_destroy`는 executor를 해제하지 않고 둔다.

`rcl_executor/trace.h`는 트레이싱 도구용 앵커(`rcl_executor_trace_*`)다.

### 2.3 rclcpp

모두 Jazzy에 없다.

| API | 용도 |
| --- | --- |
| `TypeAdapter<...>::convert_to_custom(std::shared_ptr<const ros_message_type>)`(선택) | 특수화가 이것을 주면 const callback 구독이 ROS 메시지를 복사하지 않고 참조하는 custom 객체를 받는다 |

### 2.4 rclpy

| API | 용도 | 표시 |
| --- | --- | --- |
| `Node(..., use_clock_thread=False)`, `TimeSource(..., use_clock_thread=False)` | `use_sim_time`일 때 `/clock`을 전용 스레드에서 받아 callback이 도는 동안에도 ROS time이 진행한다 | Jazzy에 없음 |
| `Future.add_done_callback(callback, *, unique=False)` | `unique=True`면 이미 등록된 같은 callback을 다시 넣지 않는다 | 인자 추가 |

### 2.5 rosbag2

| API | 용도 | 표시 |
| --- | --- | --- |
| `ros2 bag record --topic-throttle-frequency TOPIC=HZ [TOPIC=HZ ...]` | 고른 topic의 녹화 주기를 제한한다. 첫 메시지를 남기고 이후 수신 시각이 한 주기 이상 떨어진 것만 쓴다. `--use-sim-time`이면 sim time을 쓴다 | Jazzy에 없음 |
| 파라미터 `record.topic_throttle_frequency`(string 배열, 예 `/imu=10`) | composable recorder에서 같은 기능 | Jazzy에 없음 |
| `rosbag2_py.RecordOptions.topic_throttle_frequencies: Dict[str, float]` | Python에서 같은 기능 | Jazzy에 없음 |
| `ros2 bag convert` 출력 설정의 `topic_message_ranges` | topic마다 0부터 세는 닫힌 구간 `{start, end}`의 메시지만 쓴다. 범위 밖 index, 없는 topic, 뒤집힌 구간은 출력 전에 거부한다 | Jazzy에 없음 |
| `rosbag2_transport::TopicMessageRanges`와 이를 받는 `bag_rewrite` overload | C++에서 같은 기능(출력마다 map 하나) | Jazzy에 없음 |
| `ReadersManager::get_all_message_definitions` | 모든 reader의 메시지 정의 | Jazzy에 없음 |
| MCAP storage 옵션 `chunkByTopic: true`, `chunkByTopicMaxDelayMs`(기본 1000) | topic마다 chunk를 따로 써서 일부 topic만 읽을 때 그 chunk만 읽고 푼다. 파일 안 순서가 log time 순이 아니게 된다 | Jazzy에 없음 |
| `ros2 bag play --lockstep TRIGGER_TOPIC DONE_TOPIC`, `--lockstep-timeout`(기본 1 s), `--lockstep-probe`(기본 0.02 s), `--lockstep-gap`(기본 0.0002 s) | 시험할 노드가 처리하는 속도로 재생한다. 트리거 메시지를 보낸 뒤 DONE_TOPIC 메시지의 header stamp가 트리거 이상이 될 때까지 다음 메시지를 잡아 둔다. 손실 없이, 실행마다 같은 순서로 넣는다. 두 topic 모두 `std_msgs/Header`로 시작해야 한다 | Jazzy에 없음 |
| `PlayOptions::lockstep_trigger_topic`, `lockstep_done_topic`, `lockstep_timeout`, `lockstep_probe`, `lockstep_gap`, 파라미터 `play.lockstep_*`, `rosbag2_py.PlayOptions`의 같은 이름(시간은 초) | C++, composable player, Python에서 같은 기능. `PlayOptions` 크기가 바뀌어 이를 쓰는 코드는 다시 빌드해야 한다 | Jazzy에 없음 |

```bash
ros2 bag record -a --topic-throttle-frequency /imu=10 /camera/image_raw=2
ros2 bag record -a -s mcap --storage-config-file chunk_by_topic.yaml   # chunkByTopic: true
ros2 bag play run1 --lockstep /velodyne_points /cloud_registered_body   # 노드는 use_sim_time:=false
```

lockstep의 DONE_TOPIC은 노드가 한 트리거에 대해 **마지막으로** 내는 메시지로 고른다. 결과를 먼저 내고 일을 계속하는 노드(FAST-LIO의 `/Odometry`)에 맞추면, 노드가 아직 바쁠 때 다음 메시지가 들어가 짧은 구독 큐가 넘친다. ROS 시계 타이머로 처리하는 노드는 `use_sim_time:=false`로 띄운다. 재생기가 기다리는 동안 sim time이 그 타이머를 울릴 만큼 흐르지 않기 때문이다.

```yaml
output_bags:
- uri: selected_samples
  storage_id: mcap
  all_topics: true
  topic_message_ranges:
    /camera/image_raw: {start: 10, end: 42}
```

### 2.6 launch, launch_ros

| API | 용도 | 표시 |
| --- | --- | --- |
| `ros2 launch <package> <file> --dump-params` | 프로세스를 띄우지 않고 launch 파일을 평가해 노드별 최종 파라미터를 params 파일 YAML로 출력한다. composable node도 포함한다 | Jazzy에 없음 |
| `ros2launch.api.dump_params_of_a_launch_file` | 위의 Python API. 성공하면 0 | Jazzy에 없음 |
| `launch_ros.descriptions.CombinedParameterFiles` | 여러 파라미터 파일을 rcl이 적용하는 순서(뒤 파일 우선)로 합쳐 한 파일로 넘긴다 | Jazzy에 없음 |
| XML `<param><file path="a.yaml"/><file path="b.yaml"/></param>`, YAML `param: [{file: [{path: a.yaml}, {path: b.yaml}]}]` | frontend에서 같은 기능 | Jazzy에 없음 |
| `launch.utilities.select_entry_points` | 설치된 entry point를 프로세스마다 한 번만 읽고 group을 고른다 | Jazzy에 없음 |
| `launch_ros.utilities`: `DumpParamsCollector`, `DumpParamsError`, `attach_dump_params_collector`, `get_dump_params_collector`, `is_dump_params_mode` | `--dump-params`를 지원하려는 launch 확장용 | Jazzy에 없음 |

### 2.7 ros2cli

새 명령 옵션은 없다. 동작 변경은 3절에 있다. `ros2topic.api`에 `sensor_qos_matching_publishers`(발행자가 모두 reliable이면 reliable인 sensor data profile)를 더했다(Jazzy에 없음).

### 2.8 cv_bridge

| API | 용도 | 표시 |
| --- | --- | --- |
| `ROSCvMatContainer` 이동 생성자와 이동 대입 | 영상을 복사하지 않고 넘긴다 | Jazzy에 없음 |
| `ROSCvMatContainer` type adapter의 `convert_to_custom(std::shared_ptr<const Image>)` | 받은 메시지를 참조하는 container를 만든다(rclcpp의 shared 변환 hook) | Jazzy에 없음 |

### 2.9 rviz

| 대상 | 내용 | 표시 |
| --- | --- | --- |
| PointCloud2 display의 Style `Depth Fade Points` | 깊이에 따라 흐려지는 점을 GPU에서 cloud 바이트로 그린다 | Jazzy에 없음 |
| PointCloud2 display의 `Size Field`와 하위 `Min Scale`, `Max Scale`, `Autocompute Value Bounds`, `Min Value`, `Max Value` | 필드 값으로 점 크기를 바꾼다. GPU로 그릴 때(Points, Squares, Flat Squares, Spheres, Depth Fade Points)만 적용된다. 소프트웨어 렌더러에서는 적용되지 않는다 | Jazzy에 없음 |
| Image display의 `Linear input` | Bayer 영상을 linear light로 보고 sRGB로 표시한다. Bayer 영상을 받을 때만 보인다 | Jazzy에 없음 |

## 3. 켜지 않아도 바뀌는 동작

| 대상 | 바뀐 것 | 사용자가 볼 수 있는 것 |
| --- | --- | --- |
| rclcpp `MultiThreadedExecutor` | 실행 중인 mutually exclusive group에 대기 작업이 있어도 다른 스레드가 깨어 헛돌지 않는다. callback마다 guard condition을 깨우지 않고 wait에서 빠진 group을 놓을 때만 깨운다 | CPU 사용률 감소(20 ms callback 예에서 81~84% -> 2~4%), `rcl_wait` 호출 수 절반 |
| rclcpp `experimental::executors::EventsExecutor` | 늦은 timer가 이벤트를 여러 개 쌓지 않는다. 소비되지 않은 이벤트가 있으면 새 이벤트를 넣지 않는다 | 늦은 timer가 연달아 여러 번 실행되지 않는다 |
| rclcpp `executors::EventsCBGExecutor` | KEEP_LAST 구독의 대기 이벤트를 depth까지만 둔다 | 막힌 구독에서 메모리가 무한히 늘지 않는다 |
| rclcpp 구독 loan | 마지막 `shared_ptr`가 사라질 때 loan을 돌려준다 | callback 뒤에도 loan 메시지를 보관할 수 있다. 원본 헤더로 빌드한 바이너리는 원본처럼 callback 직후 돌려준다 |
| rclcpp, rclpy guard condition | rcl guard condition에 on-trigger callback이 생겼다. rclpy `EventsExecutor`가 guard condition을 받는다 | rclpy EventsExecutor에서 guard condition을 쓰는 코드가 동작한다 |
| rclcpp_action 서버 | 아직 들고 있는 goal ID로 새 goal 요청이 오면 사용자 callback 없이 거절하고 경고를 남긴다(rclpy와 같다) | 같은 ID를 다시 보내도 서버가 abort하지 않는다. 액션 서버를 만드는 패키지는 다시 빌드해야 적용된다 |
| rcl_lifecycle | 상태를 등록할 때 기존 전이가 가리키는 상태 배열을 새 배열로 옮긴다 | 전이를 등록한 뒤 상태를 더해도 해제된 메모리를 읽지 않는다 |
| rclpy executor | SIGINT로 context가 꺼지는 경쟁에서 `RCLError` 대신 `ExternalShutdownException`으로 끝난다. rolling의 task·future 수정(예외 전파, wake callback 누적)을 옮겼다. `EventsExecutor`가 `(msg, info)` callback에 두 인자를 넘긴다 | Ctrl-C 종료가 일정하다. `spin_until_future_complete` 반복 호출이 callback을 쌓지 않는다 |
| rclpy sim time | `/clock` 구독이 자기 callback group을 쓴다 | `MultiThreadedExecutor`에서 callback이 도는 동안에도 ROS time이 진행한다 |
| rclpy take, publish | 직전 take가 100 us 이상 걸린 구독은 C 단계 take 동안 GIL을 놓는다. 발행은 rcl에 넘기는 동안 GIL을 놓는다 | 큰 메시지를 주고받는 동안 다른 Python 스레드가 덜 막힌다 |
| rmw_zenoh_cpp | apt 바이너리(0.2.10)보다 새 원본 jazzy 소스를 빌드한다. 엔티티 삭제 중 교착(rmw_zenoh#994) 수정이 들어 있다 | 엔티티를 지울 때 멈추지 않는다 |
| rmw_cyclonedds | KEEP_ALL 구독에 callback 등록 전 도착한 메시지 수를 줄이지 않는다 | events 계열 executor가 등록 전 메시지를 놓치지 않는다 |
| rmw_cyclonedds | 4바이트보다 짧은 직렬화 데이터를 오류로 돌려준다. C 시퀀스를 역직렬화할 때 다시 초기화하지 않고 크기만 바꾼다 | 짧은 버퍼에서 죽지 않고, 메시지마다 메모리가 새지 않는다 |
| `ros2 topic echo`, `hz`의 `--filter` | 식을 `eval()` 대신 허용 목록 검사기로 평가한다(CVE-2024-42002) | 메시지 필드, 문자열과 리스트 메서드, 일부 내장 함수만 쓸 수 있다. 그 밖의 식은 `ValidationException`으로 거부한다 |
| image_transport, image_transport_plugins | 토픽 이름에서 노드 namespace를 접두어일 때만 뗀다 | namespace가 토픽보다 길어도 노드가 죽지 않는다. namespace 밖 절대 토픽의 transport 파라미터 이름이 `p.enable_pub_plugins`처럼 된다 |
| `ros2 topic hz`, `bw` | 발행자가 모두 reliable이면 reliable로 구독한다 | 큰 메시지(8 MiB 등)에서도 값이 나온다 |
| launch | substitution을 직접 짠 파서로 읽고 lark는 오류 보고에만 쓴다. launch 확장은 모르는 이름이 나올 때만 하나씩 로드한다. entry point는 프로세스마다 한 번 읽는다. 이벤트 handler를 색인하고 일반 화면 출력은 묶어서 낸다. `find-pkg-share` 결과를 캐시한다 | launch 평가와 시작 시간 감소. launch 도중 설치한 패키지의 entry point는 보이지 않는다. import만으로 부작용을 내는 확장은 그 이름이 나올 때까지 로드되지 않는다 |
| rosbag2 녹화 | 설치되지 않은 타입의 topic은 발행 노드의 `get_type_description` service로 정의를 받아 녹화한다(rmw_zenoh_cpp에서만). 분할마다 메타데이터가 커지지 않는다. 비압축 MCAP 녹화에서 payload 복사가 없다 | `ros2 bag record -a`가 그런 topic을 건너뛰지 않는다 |
| rosbag2 재생 | 설치되지 않은 타입은 bag에 저장된 정의로 발행한다. MCAP 읽기와 재생에서 payload 복사가 없다 | 타입 패키지 없이 재생된다. 재생 CPU 감소 |
| rosbag2 `bag_size`, `wstring` | `bag_size`를 bag 폴더 기준으로 storage를 닫은 뒤 잰다. `wstring` 필드가 있는 타입의 정의를 `.msg`로 저장한다 | 다른 cwd에서 녹화해도 크기가 맞다 |
| rviz | ROS 대기와 take·역직렬화를 `rviz_ros` 스레드에서 하고 callback만 GUI 스레드에서 실행한다(구독마다 KEEP_LAST depth까지 보관). PointCloud2를 GLSL 1.30 shader로 그린다. 16UC1·32FC1 정규화와 Bayer 변환을 shader에서 한다. map은 텍스처를 유지하고 바뀐 칸만 올린다. 크기가 맞지 않는 map update를 거부한다. SIGINT로 정상 종료한다 | 큰 영상·점군에서 표시 속도와 GUI 반응성이 오른다. Boxes, Tiles, RGBF32, 외부 transformer, float32가 아닌 xyz는 CPU 경로로 그린다. 소프트웨어 렌더러(Mesa llvmpipe 등)와 GLSL 1.30이 없는 환경에서는 shader를 쓰지 않고 CPU 경로로 그린다. 소프트웨어 렌더러에서는 shader를 CPU가 실행해 CPU 경로보다 느리기 때문이다 |
| cv_bridge | Python byte swap이 numpy 2에서 동작한다 | numpy 2에서 big-endian 영상 변환이 된다 |
| tf2_sensor_msgs | 점군을 변환할 때 입력의 `point_step`을 유지한다 | PCL 방식으로 패딩된 점군(PointXYZI 등)을 변환할 수 있다. 원본은 `AssertionError`로 실패한다 |

## 4. 주의할 점

- `ROS_EXECUTOR_CORE=1`이면 core가 guard condition의 on-trigger callback과 timer의 on-reset·schedule-change callback 칸을 쓴다. 이 칸에 사용자 callback을 따로 걸면 executor에 있는 동안 덮인다. 구독·service·client·QoS 이벤트의 callback은 2.1의 executor 칸을 써서 함께 불린다.
- 수 MB 영상이나 점군을 한 프로세스에서 계속 주고받으면 glibc malloc이 해제한 큰 블록을 커널에 돌려주고, 다음 메시지가 그 페이지에서 page fault를 다시 낸다. CPU가 크게 늘면 프로세스 환경에 `GLIBC_TUNABLES=glibc.malloc.mmap_threshold=33554432:glibc.malloc.trim_threshold=268435456`처럼 두 값을 함께 준다. 둘 중 하나만 주면 glibc의 동적 조정이 꺼져 더 나빠질 수 있다. overlay는 원본처럼 `mallopt`를 부르지 않는다.
- 이 문서의 "Jazzy에 없음" API를 쓰면 코드가 개편 overlay에 의존한다. 원본 `/opt/ros/jazzy`만으로는 빌드되지 않고, overlay로 빌드한 바이너리는 원본 위에서 심볼을 찾지 못한다.
- 반대로 원본 헤더로 빌드한 기존 바이너리는 다시 빌드하지 않아도 overlay 위에서 돈다(ABI 유지). 이런 바이너리는 원본 loan 수명 규칙을 따른다.
- numpy 2를 쓰면 cv_bridge를 numpy 2 헤더로 빌드해야 한다(`--cmake-args -DPython3_NumPy_INCLUDE_DIR=<numpy 2의 include 경로>`). numpy 1.26 헤더로 빌드한 cv_bridge는 numpy 2에서 import할 때 죽는다.
- rmw_zenoh_cpp는 원본에도 deadline·liveliness·incompatible QoS 이벤트가 없고 모든 QoS 조합을 호환으로 본다. 개편이 이 차이를 바꾸지 않았다.
