defmodule FYI.ClientTest do
  use ExUnit.Case, async: true
  use Mimic

  alias FYI.Client

  describe "new/0" do
    test "creates a Req client with default retry configuration" do
      client = Client.new()

      assert %Req.Request{} = client
      # Req stores options in the request struct
      assert client.options[:retry] == :transient
      assert client.options[:max_retries] == 3
      assert is_function(client.options[:retry_delay], 1)
    end

    test "uses exponential backoff by default" do
      client = Client.new()
      retry_delay = client.options[:retry_delay]

      # Test default backoff: 1s, 2s, 4s
      assert retry_delay.(1) == 1000
      assert retry_delay.(2) == 2000
      assert retry_delay.(3) == 4000
    end
  end

  describe "new/1 with custom options" do
    test "accepts custom Req options" do
      client = Client.new(receive_timeout: 5000)

      assert client.options[:receive_timeout] == 5000
    end
  end

  describe "new/0 with application config" do
    setup do
      original_config = Application.get_env(:fyi, :http_client)

      on_exit(fn ->
        if original_config do
          Application.put_env(:fyi, :http_client, original_config)
        else
          Application.delete_env(:fyi, :http_client)
        end
      end)
    end

    test "respects max_retries from application config" do
      Application.put_env(:fyi, :http_client, max_retries: 5)

      client = Client.new()

      assert client.options[:max_retries] == 5
    end

    test "respects custom retry_delay from application config" do
      custom_delay = fn attempt -> attempt * 500 end
      Application.put_env(:fyi, :http_client, retry_delay: custom_delay)

      client = Client.new()

      assert client.options[:retry_delay] == custom_delay
      assert client.options[:retry_delay].(1) == 500
    end

    test "allows disabling retries with max_retries: 0" do
      Application.put_env(:fyi, :http_client, max_retries: 0)

      client = Client.new()

      assert client.options[:max_retries] == 0
    end
  end

  describe "post/2" do
    test "returns ok tuple with response on success" do
      url = "https://example.com/webhook"
      payload = %{text: "Hello"}

      Req
      |> expect(:post, fn _client, opts ->
        assert opts[:url] == url
        assert opts[:json] == payload
        {:ok, %Req.Response{status: 200, body: "ok"}}
      end)

      assert {:ok, %Req.Response{status: 200, body: "ok"}} =
               Client.post(url, json: payload)
    end

    test "returns error tuple on failure" do
      url = "https://example.com/webhook"

      Req
      |> expect(:post, fn _client, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} = Client.post(url)
    end

    test "handles 4xx responses" do
      url = "https://example.com/webhook"

      Req
      |> expect(:post, fn _client, _opts ->
        {:ok, %Req.Response{status: 404, body: "Not Found"}}
      end)

      assert {:ok, %Req.Response{status: 404, body: "Not Found"}} = Client.post(url)
    end

    test "handles 5xx responses (with retries configured)" do
      url = "https://example.com/webhook"

      Req
      |> expect(:post, fn _client, _opts ->
        {:ok, %Req.Response{status: 500, body: "Internal Server Error"}}
      end)

      assert {:ok, %Req.Response{status: 500, body: "Internal Server Error"}} =
               Client.post(url)
    end

    test "accepts custom headers option" do
      url = "https://example.com/webhook"
      headers = [{"authorization", "Bearer token"}]

      Req
      |> expect(:post, fn _client, opts ->
        # Headers are merged with the client's defaults
        assert is_list(opts[:headers])
        {:ok, %Req.Response{status: 200, body: "ok"}}
      end)

      assert {:ok, %Req.Response{status: 200, body: "ok"}} =
               Client.post(url, headers: headers)
    end

    test "accepts receive_timeout option" do
      url = "https://example.com/webhook"

      Req
      |> expect(:post, fn _client, opts ->
        assert opts[:receive_timeout] == 10_000
        {:ok, %Req.Response{status: 200, body: "ok"}}
      end)

      assert {:ok, %Req.Response{status: 200, body: "ok"}} =
               Client.post(url, receive_timeout: 10_000)
    end
  end
end
