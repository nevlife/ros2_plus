# ros2_plus 미출시

기준: ROS 2 Jazzy overlay, [ros2_plus.repos](../../ros2_plus.repos)의 포크 `jazzy` 브랜치.

<!--
  변경을 커밋할 때마다 여기에 한 줄을 더한다. 형식은 template.md를 따른다.
  API와 동작의 상세는 ../api.md에 있다.
-->

## 기능

- `cv_bridge`: `cvtColorToImageMsg`, `ROSCvMatContainer` 이동, 수신 메시지를 참조하는 `convert_to_custom`, `imgmsg_to_cv2_view`, CUDA OpenCV용 `GpuMat` type adapter(vision_opencv#519)
- `image_transport`: `TypeAdaptedPublisher`, `TypeAdaptedCameraPublisher`, `create_type_adapted_subscription`(image_common#301)
- `image_transport_plugins`: 무손실 depth transport `depthz`(`depthz_image_transport`, image_transport_plugins#238)
- `launch_ros`: `ros2 launch --dump-params`(launch_ros#584), `CombinedParameterFiles`와 frontend `<param><file/><file/></param>`(launch_ros#530)
- `pcl_conversions`: PCL 타입 `rclcpp::TypeAdapter`, 복사 없는 XYZ Eigen map
- `rcl`: 같은 context의 topic, service, action을 직렬화 없이 넘기는 broker(`RCL_INTRA_PROCESS=1`, rmw_zenoh_cpp). generic·직렬화 구독은 발행마다 한 번 직렬화를 공유한다
- `rcl`: guard condition on-trigger callback, executor용 readiness callback 칸, timer 일정 변경 callback(rcl#1352)
- `rcl_executor`: rcl 아래 공통 executor core(FIFO, WAIT_SET, PRIORITY 정책, 파티션 모드, 스레드 시작 hook, 외부 대기 소스, 트레이스 앵커)
- `rclcpp`: `RclExecutor`, `ROS_EXECUTOR_CORE=1`이면 기본 executor가 core로 돈다
- `rclcpp`: `declare_parameters_atomically`(rclcpp#1991), `NodeOptions::time_source`로 TimeSource 공유(rclcpp#2673), type adapter `convert_to_custom(shared_ptr)` hook
- `rclpy`: `rclpy.experimental.RclExecutor`, `Executor.spin_some`(rclpy#486), `use_clock_thread`
- `rclpy`: `Publisher.borrow_loaned_message`, 구독 loan(rclpy#889), Python type adapter 시제품
- `rclpy_components`: Python component container와 C++·Python 혼합 컨테이너 `component_container_mixed`(rclpy#599, rclpy#575)
- `rmw_zenoh_cpp`: SHM 위 고정 크기 타입 loan(rmw_zenoh#175)
- `ros2_numpy`: `get_xyz_points_view`
- `rosbag2`: 녹화 topic 주기 제한(rosbag2#2478), `ros2 bag convert` 메시지 범위(rosbag2#2500), MCAP `chunkByTopic`(rosbag2#2220)
- `rosbag2`: 설치되지 않은 타입 녹화(rmw_zenoh_cpp)와 재생(rosbag2#1373, rosbag2#1428)
- `rosidl_generator_py`: `RCLPY_MESSAGE_ARRAYS=numpy`의 읽기 전용 numpy 수신 view, loan의 쓰기 가능한 view
- `rviz`: PointCloud2 `Depth Fade Points`(rviz#1648), `Size Field`(rviz#884), Image `Linear input`

## 성능

- `cv_bridge`, `tf2_sensor_msgs`, `ros2_numpy`: 영상·점군 변환의 복사 감소
- `image_view`: 새 frame마다 창 스레드를 깨운다(image_pipeline#1164)
- `launch`: substitution 파서 교체, 이벤트 handler 색인, 화면 출력 묶음, `find-pkg-share` 캐시, launch 확장 지연 로드, entry point 1회 읽기
- `launch_ros`: Node마다 하던 entry point 선택을 한 번으로
- `rclcpp`: callback group 엔티티 추가 상각 O(1)(rclcpp#2942)
- `rclcpp`: `MultiThreadedExecutor`가 callback마다 guard condition을 깨우지 않는다(rclcpp#1148)
- `rclpy`: take가 오래 걸리는 구독은 C 단계 take 동안 GIL을 놓는다(rclpy#1025), 응답 완료 때 대기 요청 전체 스캔 제거(rclpy#1703)
- `rmw_zenoh_cpp`: 조각 payload를 0으로 채우지 않고 모은다
- `ros2cli`: `ros2 topic hz`, `bw`, `delay`를 EventsExecutor로 spin, 시작할 때 fd table을 미리 키운다
- `rosbag2`: MCAP 읽기·재생·비압축 녹화의 payload 복사 제거, 분할마다 커지던 메타데이터(rosbag2#2490)
- `rosidl_generator_py`: 변환 클래스와 필드 이름 캐시(rosidl_python#218, rosidl_python#265), 숫자 배열 setter 일괄 복사, 생성기 미리 import
- `rosidl_runtime_py`: 배열을 dict로 바꿀 때 `tolist` 일괄 변환
- `rosidl_typesupport_fastrtps`: 역직렬화에서 시퀀스 0 채우기 제거, 중첩 plain 시퀀스 일괄 복사
- `rviz`: PointCloud2 GLSL shader 경로, 16UC1·32FC1 정규화와 Bayer 변환 shader, map 부분 업로드(rviz#937), ROS 대기와 역직렬화를 `rviz_ros` 스레드로

## 버그 수정

- `cv_bridge`: numpy 2에서 byte swap, compressed 영상의 `desired_encoding` 오류
- `cv_bridge`: Bayer, YUY2 영상을 같은 encoding의 다른 bit depth로 바꾸지 못하던 것(vision_opencv#540의 일부, rolling에만 있던 수정)
- `rcl`: `rmw_create_subscription` 실패 원인이 "invalid allocator"로 덮이던 것
- `rclcpp`: `EventsExecutor` 늦은 timer 몰림(rclcpp#2771), `EventsCBGExecutor` 큐 무한 증가(rclcpp#3213), 소유하지 않은 wait set의 `remove_*`(rclcpp#3294)
- `rclcpp`: exclusive group이 바쁠 때 `MultiThreadedExecutor` busy loop, 구독 loan을 마지막 `shared_ptr`가 사라질 때 반환(rclcpp#3280 방식)
- `rclpy`: SIGINT 뒤 spin이 멈추거나 `RCLError`로 끝나던 것, rolling의 executor 수정(rclpy#1718, #1702, #1643, #1662, #1669), sim time에서 callback 중 `/clock` 멈춤(rclpy#792), EventsExecutor `(msg, info)` callback 인자
- `rclpy`: 발행이 GIL을 쥔 채 미들웨어 lock을 기다려, type adapter를 쓰는 프로세스에서 발행 스레드와 수신 스레드가 서로 기다리며 멈추던 것
- `rmw_cyclonedds_cpp`: KEEP_ALL 구독에 등록 전 메시지 수를 0으로 알리던 것
- `rmw_zenoh_cpp`: 엔티티 삭제 중 교착(rmw_zenoh#994)
- `rmw_zenoh_cpp`: loan용 공유 메모리 pool을 만들지 못하면(예: 낮은 `ulimit -l`) borrow마다 다시 만들던 것. 이제 경고를 한 번 남기고 heap으로 loan을 준다
- `ros2topic`: 큰 메시지에서 `hz`, `bw`가 값을 내지 않던 것, 공용 QoS preset을 제자리에서 바꾸던 것, SIGINT 종료 코드
- `rosbag2`: 다른 cwd에서 녹화한 `bag_size`, `wstring` 필드 타입 정의 저장
- `rviz`: SIGINT 종료 때 use-after-free, 크기가 맞지 않는 map update의 heap 쓰기, swatch 누수(rviz#1843), 구독을 지운 display가 callback을 받던 것

## 워크플로

- `rcl`: rmw_zenoh_cpp에서 DDS를 전제한 시험 기대값 조정(rcl#1192, #1197, #1164)
- `system_tests`: 개편 스위치별 기대값과 개편 기능 시험 `test_overhaul`
- `tools`: 시스템 시험 실행기 `system_test_matrix.py`, 두 OS 비교 `compare_system_tests.py`, Ubuntu 22.04 컨테이너 `tools/jammy`
- `tools`: 변경분 정적 분석 `static_check.py`, 측정 코어 고정 `pinned_run.py`
- `tools`: rosdoc2 생성 참조 빌드 `build_docs.sh`, [시험 문서](../testing.md)
- `colcon-ros-cargo`: 설치 절차가 포크를 쓴다. cargo 설정을 워크스페이스 맨 위가 아니라 패키지의 build 디렉터리에 써서, 같은 워크스페이스의 zenoh-c `cargo --locked` 빌드가 깨지지 않는다

## 호환성이 깨지는 변경

1. 다시 생성한 메시지 패키지의 `byte[]` 필드는 `bytes`다. list 대입은 계속 되고 `ros2 topic echo` 형식은 원본과 같다.

   ```python
   # 이전
   msg.data == [b'\x01', b'\x02']
   # 이후
   msg.data == b'\x01\x02'
   ```

2. broker를 쓰면(`RCL_INTRA_PROCESS=1`, rmw_zenoh_cpp) 같은 context에서 받은 메시지의 `from_intra_process`가 `true`다.
3. launch 확장은 그 이름이 나올 때 로드하고 entry point는 프로세스마다 한 번 읽는다. import 부작용에 기대는 확장과 launch 도중 설치한 패키지는 영향을 받는다.
