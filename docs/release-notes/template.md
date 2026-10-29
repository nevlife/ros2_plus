# ros2_plus <버전>

기준: ROS 2 Jazzy overlay, [ros2_plus.repos](../../ros2_plus.repos)의 포크 커밋 `<커밋 또는 태그>`.

<!--
  출시할 때 unreleased.md를 <버전>.md로 옮기고 이 템플릿으로 unreleased.md를 새로 만든다.
  포크의 CHANGELOG.rst는 upstream 것 그대로 두고 고치지 않는다. 변경 기록은 이 파일 하나에 둔다.
  항목은 한 줄로 쓰고 영역(포크 패키지 이름) 순으로 정렬한다. 그래야 병합 충돌이 줄어든다.
  upstream 이슈나 PR을 옮긴 항목은 그 번호를 붙인다(예: rclcpp#2771).
  측정값과 설계 근거는 여기 적지 않는다.
-->

## 기능

- `rclcpp`: 예시 문장

## 성능

- `rclcpp`: 예시 문장

## 버그 수정

- `rclcpp`: 예시 문장

## 워크플로

- `tools`: 예시 문장

## 호환성이 깨지는 변경

1. 예시

   ```python
   # 이전
   msg.data == [b'\x01', b'\x02']
   # 이후
   msg.data == b'\x01\x02'
   ```
