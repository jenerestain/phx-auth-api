defmodule PhxAuthApiWeb.UserControllerTest do
  use PhxAuthApiWeb.ConnCase

  alias PhxAuthApi.Auth
  alias PhxAuthApi.Auth.User
  alias PhxAuthApi.Auth.Verify

  @create_attrs %{password: "some password", username: "some username"}
  @other_attrs %{password: "some password 2", username: "some username 2"}
  @update_attrs %{password: "some updated password", username: "some updated username"}
  @invalid_attrs %{password: nil, username: nil}

  def fixture(:user) do
    {:ok, user} = Auth.create_user(@create_attrs)
    user
  end

  def fixture(:second_user) do
    {:ok, user} = Auth.create_user(@other_attrs)
    user
  end

  def fixture(:token) do
    {:ok, jwt, _} = Verify.authenticate_user(@create_attrs.username, @create_attrs.password)
    jwt
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn = get conn, user_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, user_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "username" => "some username"}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]
    setup [:create_second_user]
    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user, jwt: jwt} do
      conn = put_req_header(conn, "authorization", jwt)
      conn = put conn, user_path(conn, :update, user), user: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, user_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "username" => "some updated username"}
    end

    test "user can't update other users data", %{conn: conn, second_user: second_user, jwt: jwt} do
      conn = put_req_header(conn, "authorization", jwt)
      conn = put conn, user_path(conn, :update, second_user), user: @update_attrs
      assert %{"errors" => %{"detail" => "unauthenticated"}} = json_response(conn, 401)
    end

    test "renders errors when data is invalid", %{conn: conn, user: user, jwt: jwt} do
      conn = put_req_header(conn, "authorization", jwt)
      conn = put conn, user_path(conn, :update, user), user: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]
    setup [:create_second_user]

    test "deletes chosen user", %{conn: conn, user: user, jwt: jwt} do
      conn = put_req_header(conn, "authorization", jwt)
      conn = delete conn, user_path(conn, :delete, user)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, user_path(conn, :show, user)
      end
    end

    test "user can't delete other user", %{conn: conn, second_user: second_user, jwt: jwt} do
      conn = put_req_header(conn, "authorization", jwt)
      conn = put conn, user_path(conn, :delete, second_user), user: @update_attrs
      assert %{"errors" => %{"detail" => "unauthenticated"}} = json_response(conn, 401)
    end
  end

  defp create_user(_) do
    user = fixture(:user)
    jwt = fixture(:token)
    {:ok, user: user, jwt: jwt}
  end

  defp create_second_user(_) do
    user = fixture(:second_user)
    {:ok, second_user: user}
  end
end
