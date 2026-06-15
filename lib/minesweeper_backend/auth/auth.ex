defmodule MinesweeperBackend.Auth do
  use MyApp.Web, :channel

  # 클라이언트가 채널에 참여(join)할 때 호출
  def join("room:lobby", _payload, socket) do
    {:ok, socket}
  end

  # 클라이언트가 "new_msg" 이벤트를 보냈을 때 처리
  def handle_in("new_msg", %{"body" => body}, socket) do
    # 현재 채널에 참여한 모든 사람에게 메시지 브로드캐스트
    broadcast!(socket, "new_msg", %{body: body})
    {:noreply, socket}
  end
end
