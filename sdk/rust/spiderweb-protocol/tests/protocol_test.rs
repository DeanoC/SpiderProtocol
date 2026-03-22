use spiderweb_protocol::generated::*;
use spiderweb_protocol::protocol::*;

#[test]
fn base64_round_trip() {
    let encoded = encode_data_b64("hello");
    let decoded = decode_data_b64(&encoded).unwrap();
    assert_eq!(decoded, b"hello");
}

#[test]
fn control_alias_request_serializes_workspace_fields() {
    let request = ControlRequestEnvelope::WorkspaceBindSet(ControlEnvelope {
        channel: Channel::Control,
        message_type: ControlMessageType::WorkspaceBindSet,
        id: Some("req-1".into()),
        ok: None,
        payload: Some(WorkspaceBindSetRequest {
            workspace_id: "ws-1".into(),
            workspace_token: Some("tok".into()),
            bind_path: "/app".into(),
            target_path: "/projects/demo/app".into(),
        }),
    });
    let raw = stringify_control_request(&request).unwrap();
    assert!(raw.contains("\"workspace_id\":\"ws-1\""));
    assert!(raw.contains("\"workspace_token\":\"tok\""));
    assert!(!raw.contains("\"project_id\""));
}

#[test]
fn parse_rejects_invalid_channel() {
    let error = parse_control_request(r#"{"channel":"acheron","type":"control.version","id":"x","payload":{"protocol":"spiderweb-control"}}"#).unwrap_err();
    assert_eq!(error.code, "invalid_channel");
}

#[test]
fn parse_rejects_invalid_tag() {
    let error = parse_acheron_request(r#"{"channel":"acheron","type":"acheron.t_version","tag":"x","msize":1,"version":"acheron-1"}"#).unwrap_err();
    assert_eq!(error.code, "invalid_tag");
}

#[test]
fn control_event_round_trip_supports_mount_graph_delta() {
    let raw = r#"{"channel":"control","type":"control.mount_graph_delta","payload":{"mount_session_id":"mount-1","generation":2,"delta":{"ops":[]}}}"#;
    let envelope = parse_control_event(raw).unwrap();
    match envelope {
        ControlEventEnvelopeEnum::MountGraphDelta(inner) => {
            assert_eq!(
                inner.payload.unwrap(),
                serde_json::json!({
                    "mount_session_id": "mount-1",
                    "generation": 2,
                    "delta": { "ops": [] }
                })
            );
        }
    }

    let serialized = stringify_control_event(&ControlEventEnvelopeEnum::MountGraphDelta(ControlEnvelope {
        channel: Channel::Control,
        message_type: ControlMessageType::MountGraphDelta,
        id: None,
        ok: None,
        payload: Some(serde_json::json!({
            "mount_session_id": "mount-1",
            "generation": 3
        })),
    }))
    .unwrap();
    assert!(serialized.contains("\"type\":\"control.mount_graph_delta\""));
}

#[tokio::test(flavor = "current_thread")]
async fn control_client_matches_by_id() {
    let response = r#"{"channel":"control","type":"control.version_ack","id":"req-1","ok":true,"payload":{"protocol":"spiderweb-control","acheron_runtime":"acheron-1","acheron_node":"spiderweb-fs","acheron_node_proto":2}}"#.to_string();
    let mut client = ControlClient::new(MockTextTransport::new([response]));
    let envelope = client.negotiate_version("req-1").await.unwrap();
    match envelope {
        ControlResponseEnvelope::VersionAck(inner) => {
            assert_eq!(inner.id.as_deref(), Some("req-1"))
        }
        other => panic!("unexpected response: {other:?}"),
    }
}

#[tokio::test(flavor = "current_thread")]
async fn control_client_surfaces_errors_without_id() {
    let error_envelope =
        r#"{"channel":"control","type":"control.error","ok":false,"error":{"code":"denied","message":"nope"}}"#.to_string();
    let mut client = ControlClient::new(MockTextTransport::new([error_envelope]));
    let error = client.negotiate_version("req-1").await.unwrap_err();
    assert_eq!(error.code, "denied");
}

#[tokio::test(flavor = "current_thread")]
async fn acheron_client_pumps_events_before_response() {
    let event =
        r#"{"channel":"acheron","type":"acheron.e_fs_inval","payload":{"node":42,"what":"data"}}"#
            .to_string();
    let response = r#"{"channel":"acheron","type":"acheron.r_fs_hello","tag":3,"ok":true,"payload":{"protocol":"spiderweb-fs","proto":2,"capabilities":{"exports":true}}}"#.to_string();
    let mut client = AcheronClient::new(MockTextTransport::new([event, response]));
    let mut saw_event = false;
    let response = client
        .request_with_events(
            AcheronRequestEnvelope::FsTHello(AcheronPayloadEnvelope {
                channel: Channel::Acheron,
                message_type: AcheronMessageType::FsTHello,
                tag: Some(3),
                ok: None,
                payload: Some(FsHelloRequest {
                    protocol: NODE_FS_PROTOCOL.into(),
                    proto: NODE_FS_PROTO,
                    auth_token: None,
                    node_id: None,
                    node_secret: None,
                }),
            }),
            |event| {
                if matches!(event, AcheronEventEnvelopeEnum::FsEvtInval(_)) {
                    saw_event = true;
                }
                Ok(())
            },
        )
        .await
        .unwrap();
    assert!(saw_event);
    assert!(matches!(response, AcheronResponseEnvelope::FsRHello(_)));
}

#[tokio::test(flavor = "current_thread")]
async fn acheron_client_maps_fs_errors() {
    let error_envelope = r#"{"channel":"acheron","type":"acheron.err_fs","tag":5,"ok":false,"error":{"errno":2,"message":"missing"}}"#.to_string();
    let mut client = AcheronClient::new(MockTextTransport::new([error_envelope]));
    let error = client
        .request(AcheronRequestEnvelope::FsTClose(AcheronHandleEnvelope {
            channel: Channel::Acheron,
            message_type: AcheronMessageType::FsTClose,
            tag: Some(5),
            ok: None,
            handle: 1,
            payload: Some(EmptyObject::default()),
        }))
        .await
        .unwrap_err();
    assert_eq!(error.code, "acheron_fs_error");
}

#[tokio::test(flavor = "current_thread")]
async fn acheron_client_surfaces_errors_without_tag() {
    let error_envelope =
        r#"{"channel":"acheron","type":"acheron.error","ok":false,"error":{"code":"busy","message":"later"}}"#.to_string();
    let mut client = AcheronClient::new(MockTextTransport::new([error_envelope]));
    let error = client
        .request(AcheronRequestEnvelope::FsTHello(AcheronPayloadEnvelope {
            channel: Channel::Acheron,
            message_type: AcheronMessageType::FsTHello,
            tag: Some(3),
            ok: None,
            payload: Some(FsHelloRequest {
                protocol: NODE_FS_PROTOCOL.into(),
                proto: NODE_FS_PROTO,
                auth_token: None,
                node_id: None,
                node_secret: None,
            }),
        }))
        .await
        .unwrap_err();
    assert_eq!(error.code, "busy");
}
