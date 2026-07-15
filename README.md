# 2026-mini-project-backend

작성은 새벽 4시 15분에 할거 없는 문태영이 함

# remote 추가

혹시라도 모를 **전재민**을 위해 추가^^

```sh
git remote add origin https://github.com/2026-mini-project/backend.git
git branch -M main
git pull origin main
```

# 타입 정의

## APIError

```typescript
type APIError = {
    "message": string
};
```

## APIUser

```typescript
type APIUser = {
    "id": string, // SessionId임
    "name": string,
};
```

## APIRoom

```typescript
type APIRoom = {
    "id": string,
    "name": string,
    "owner": string, // SessionId임
    "private": boolean, // 비공개 방인지 여부
    "full": boolean // 방이 꽉 찼는지 여부
};
```

# API flow

멀티플레이이니만큼 웹소켓이 필수~~(HTTP response로 이상한짓 하기 싫으면 웹소켓 쓰세요)~~  
**모든 Request, Response의 Content-Type은 application/json**

**만약 서버에서 오류가 나면 (APIError)[#apierror] 타입으로 오류를 반환할 것**
오류났는데 status 200대 반환하면 숨집니다(진심임)  
사실 오류났을때 아무런 body 반환 안해도 되는데 반환 안하는 루트 말해주시고 status 말해주셔야함  

## GET /

서버 상태를 확인하는 API

### Response

```json
{
    "running": true
}
```

## GET /session

세션을 가져오는 API

### Request

|헤더|타입|
|-|-|
|Authorization|sessionId(string)|

### Response

[APIUser](#apiuser)

## POST /session/refresh

세션 ID의 만료를 연장하는 API  
기본 만료 시간은 1시간이며, 이 API를 호출하면 세션 ID의 만료가 1시간 더 연장된다. (서버 설정에 따라 다를 수 있음)

### Request

|헤더|타입|
|-|-|
|Authorization|sessionId(string)|

### Response

[APIUser](#apiuser)

## DELETE /session

현재 세션을 삭제하는 API

### Request

|헤더|타입|
|-|-|
|Authorization|sessionId(string)|

### Response

204 No Content

## POST /session

세션을 새로 생성하는 API  
로그인은 없고, 닉네임을 입력 받는다.   

**여기서 반환하는 세션 ID는 서버에 저장되어야하고, 그 세션 ID로 닉네임을 가져올 수 있어야함**  

~~ID 넘버로 쓰고싶다고요? 꼬우면 앞에 prefix 붙이세요~~

### Request

```json
{
    "name": "string"
}
```

### Response

[APIUser](#apiuser)

## GET /rooms

공개 방 목록을 가져오는 API  
비공개 방은 목록에 나오지 않음

### Request

|헤더|타입|
|-|-|
|Authorization|sessionId(string)|

### Response

[APIRoom](#apiroom)[]

## GET /rooms/:id

id를 가진 방을 가져오는 API

### Request

|헤더|타입|
|-|-|
|Authorization|sessionId(string)|

### Response

[APIRoom](#apiroom)

## POST /rooms

방을 만드는 API

### Request

|헤더|타입|
|-|-|
|Authorization|sessionId(string)|

```json
{
    "name": "string",
    "private": false
}
```

`private` 생략 시 `false`

### Response

[APIRoom](#apiroom)

# WebSocket

**웹소켓 플로우는 FigJam에 해뒀음**  
[FigJam](https://www.figma.com/board/rfGW6n08AYT5GbXnG5e52J/2026-mini-project)

Phoenix Channel이 아니라 **HTML5 WebSocket API** 기준이다.  
`event.data`로 받고 `ws.send(...)`로 보낸다.

## 메시지 형식

모든 프레임은 JSON **텍스트** 한 줄이다.

```json
["이벤트이름"]
```

또는 payload가 있을 때:

```json
["이벤트이름", { ... }]
```

### 클라이언트 예시

```js
const ws = new WebSocket("ws://localhost:4000/socket");

ws.onopen = () => {
  ws.send(JSON.stringify(["identify", { sessionId: "..." }]));
};

ws.onmessage = (event) => {
  const parsed = JSON.parse(event.data);
  const [name, payload] = parsed;
  // payload는 생략된 이벤트면 undefined
};
```

## 연결 순서

1. REST API로 방 정보 조회
2. `new WebSocket("ws://<host>/socket")` (query param 없음)
3. `identify` → `welcome` (5초 이내, 실패/타임아웃 시 연결 종료)
4. `ping` / `pong` heartbeat (`pingInterval` ms마다 ping, `pingInterval + 3초` 동안 pong 없으면 클라이언트가 close)
5. `join` → `joined`
6. 방장은 필요하면 `settings`로 보드 설정
7. `ready` / `startGame` / 인게임 이벤트

# 이벤트 요약 (WebSocket)

| client → server (`ws.send`) | server → client (`onmessage`) | payload |
|-----------------------------|-------------------------------|---------|
| `["identify", {sessionId}]` | `["welcome", {pingInterval}]` | |
| `["ping"]` | `["pong"]` | (없음) |
| `["join", {id: roomId}]` | `["joined", APIUser[]]` | |
| `["ready"]` | `["ready", APIUser]` | |
| `["cancelReady"]` | `["cancelReady", APIUser]` | |
| `["settings", {mines, size}]` | `["done"]` | 방장 전용, 다음 게임부터 적용 |
| `["startGame"]` | `["gameStarted"]`, `["gameBoard", {data}]` | `{data: base85}` |
| `["boardClick", {x, y}]` | `["boardClick", {x, y, by}]`, `["turn", {userId}]` | |
| `["flag", {x, y}]` | `["flag", {x, y, by}]`, `["turn", {userId}]` | |
| `["gameClear"]` | `["gameClear", {winner}]` | `{winner: APIUser}` |
| | `["error", APIError]` | |

# 개발 환경

`mix compile` 시 시스템 Erlang/OTP의 `public_key` 패키지에서 `include/OTP-PUB-KEY.hrl`이 누락되면
`phx.gen.cert` 의존성 컴파일이 실패한다 (우리 코드와 무관). Ubuntu/Debian 계열에서는 다음으로
복구할 것:

```sh
sudo apt-get install --reinstall erlang-public-key
```
