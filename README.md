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
    "name": "string"
}
```

### Response

[APIRoom](#apiroom)

# WebSocket

**웹소켓 플로우는 FigJam에 해뒀음**  
[FigJam](https://www.figma.com/board/rfGW6n08AYT5GbXnG5e52J/2026-mini-project)

