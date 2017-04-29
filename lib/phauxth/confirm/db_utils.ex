defmodule Phauxth.Confirm.DB_Utils do
  @moduledoc """
  User confirmation helper functions for use with Ecto.
  """

  import Ecto.Changeset
  alias Phauxth.Config

  @doc """
  Add a confirmation token to the user changeset.

  Add the following three entries to your user schema:

      field :confirmation_token, :string
      field :confirmation_sent_at, Ecto.DateTime
      field :confirmed_at, Ecto.DateTime

  ## Examples

  In the following example, the 'add_confirm_token' function is called with
  a key generated by 'Phauxth.Confirm.gen_token_link':

      changeset |> Phauxth.Confirm.DB_Utils.add_confirm_token(key)

  """
  def add_confirm_token(user, key) do
    change(user, %{confirmation_token: key, confirmation_sent_at: Ecto.DateTime.utc})
  end

  @doc """
  Add a reset token to the user changeset.

  Add the following two entries to your user schema:

      field :reset_token, :string
      field :reset_sent_at, Ecto.DateTime

  As with 'add_confirm_token', the function 'Phauxth.Confirm.gen_token_link'
  can be used to generate the token and link.
  """
  def add_reset_token(user, key) do
    change(user, %{reset_token: key, reset_sent_at: Ecto.DateTime.utc})
  end

  @doc """
  Change the 'confirmed_at' value in the database to the current time.
  """
  def user_confirmed(user) do
    change(user, %{confirmed_at: Ecto.DateTime.utc}) |> Config.repo.update
  end

  @doc """
  Add the password hash for the new password to the database.

  If the update is successful, the reset_token and reset_sent_at
  values will be set to nil.

  ## Options

  Three options are available:

    * password_strength_func - a function to check the strength of the password
      * the default function checks that the password is at least 8 characters long
    * hash_name - name for the password hash (to be used when calling the database)
      * the default is password_hash
    * hash_func - the hash function to be used
      * the default function is Comeonin.Bcrypt.hashpwsalt

  ## Examples

  To change the password strength function:

      Phauxth.Confirm.DB_Utils.password_reset(user, password, &strong_password/1)

  To use a different hash function:

      Phauxth.Confirm.DB_Utils.password_reset(user, password, &Argon2.hash_pwd_salt/1)

  """
  def password_reset(user, password, opts \\ []) do
    strength_func = Keyword.get(opts, :password_strength_func, &min_len_8_chars/1)
    strength_func.(password)
    |> reset_update_repo(user, opts)
  end

  @doc """
  Function used to check if a confirmation token has expired.
  """
  def check_time(nil, _), do: false
  def check_time(sent_at, valid_secs) do
    (sent_at |> Ecto.DateTime.to_erl
     |> :calendar.datetime_to_gregorian_seconds) + valid_secs >
    (:calendar.universal_time |> :calendar.datetime_to_gregorian_seconds)
  end

  defp reset_update_repo({:ok, password}, user, opts) do
    hash_name = Keyword.get(opts, :hash_name, :password_hash)
    hash_func = Keyword.get(opts, :hash_func, &Comeonin.Bcrypt.hashpwsalt/1)
    Config.repo.transaction(fn ->
      user = change(user, %{hash_name => hash_func.(password)})
      |> Config.repo.update!

      change(user, %{reset_token: nil, reset_sent_at: nil})
      |> Config.repo.update!
    end)
  end
  defp reset_update_repo({:error, message}, _, _) do
    {:error, message}
  end

  defp min_len_8_chars(password) when is_binary(password) do
    String.length(password) >= 8 and
      {:ok, password} || {:error, "The password is too short. At least 8 characters."}
  end
  defp min_len_8_chars(_), do: {:error, "The password should be a string"}
end
