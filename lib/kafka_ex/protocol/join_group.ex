defmodule KafkaEx.Protocol.JoinGroup do
  import KafkaEx.Protocol.Common

  @moduledoc """
  Implementation of the Kafka JoinGroup request and response APIs
  """
  @protocol_type "consumer"
  @strategy_name "assign"
  @metadata_version 0

  defmodule Request do
    @moduledoc false
    defstruct correlation_id: nil,
      client_id: nil, member_id: nil,
      group_name: nil, topics: nil,
      session_timeout: nil
    @type t :: %Request{
      correlation_id: integer,
      client_id: binary,
      member_id: binary,
      group_name: binary,
      topics: [binary],
      session_timeout: integer,
    }
  end

  defmodule Response do
    @moduledoc false
    defstruct error_code: nil, generation_id: 0, leader_id: nil, member_id: nil, members: []
    @type t :: %Response{error_code: atom | integer, generation_id: integer,
                         leader_id: binary, member_id: binary, members: [binary]}
  end

  @spec create_request(Request.t) :: binary
  def create_request(join_group_req) do
    metadata =
      << @metadata_version :: 16-signed,
         length(join_group_req.topics) :: 32-signed, topic_data(join_group_req.topics) :: binary,
         0 :: 32-signed
         >>

    KafkaEx.Protocol.create_request(
      :join_group, join_group_req.correlation_id, join_group_req.client_id
    ) <>
      << byte_size(join_group_req.group_name) :: 16-signed, join_group_req.group_name :: binary,
         join_group_req.session_timeout :: 32-signed,
         byte_size(join_group_req.member_id) :: 16-signed, join_group_req.member_id :: binary,
         byte_size(@protocol_type) :: 16-signed, @protocol_type :: binary,
         1 :: 32-signed, # We always have just one GroupProtocl
         byte_size(@strategy_name) :: 16-signed, @strategy_name :: binary,
         byte_size(metadata) :: 32-signed, metadata :: binary
         >>
  end

  @spec parse_response(binary) :: Response.t
  def parse_response(<< _correlation_id :: 32-signed, error_code :: 16-signed, generation_id :: 32-signed,
                       protocol_len :: 16-signed, _protocol :: size(protocol_len)-binary,
                       leader_len :: 16-signed, leader :: size(leader_len)-binary,
                       member_id_len :: 16-signed, member_id :: size(member_id_len)-binary,
                       members_size :: 32-signed, rest :: binary >>) do
    members = parse_members(members_size, rest, [])
    %Response{error_code: KafkaEx.Protocol.error(error_code), generation_id: generation_id,
              leader_id: leader, member_id: member_id, members: members}
  end

  defp parse_members(0, <<>>, members), do: members
  defp parse_members(size, << member_len :: 16-signed, member :: size(member_len)-binary,
                              meta_len :: 32-signed, _metadata :: size(meta_len)-binary,
                              rest :: binary >>, members) do
    parse_members(size - 1, rest, [member|members])
  end
end
