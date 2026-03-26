const std = @import("std");

pub const ParseError = error{
    InvalidEnvelope,
    MissingField,
    InvalidType,
    UnsupportedType,
    InvalidBase64,
};

pub const Channel = enum {
    control,
    acheron,
};

pub const ControlType = enum {
    version,
    version_ack,
    connect,
    connect_ack,
    session_attach,
    session_status,
    mount_attach,
    mount_graph_delta,
    mount_file_read,
    mount_file_write,
    mount_path_readlink,
    mount_path_mkdir,
    mount_path_unlink,
    mount_path_rmdir,
    mount_path_rename,
    mount_path_symlink,
    mount_path_setxattr,
    mount_path_getxattr,
    mount_path_listxattr,
    mount_path_removexattr,
    mount_path_lock,
    mount_path_setattr,
    session_resume,
    session_list,
    session_close,
    session_restore,
    session_history,
    ping,
    pong,
    metrics,
    auth_status,
    auth_rotate,
    node_invite_create,
    node_join_request,
    node_join_pending_list,
    node_join_approve,
    node_join_deny,
    node_join,
    node_ensure,
    node_lease_refresh,
    venom_bind,
    venom_upsert,
    venom_get,
    node_list,
    node_get,
    node_delete,
    workspace_create,
    workspace_update,
    workspace_delete,
    workspace_list,
    workspace_get,
    workspace_template_list,
    workspace_template_get,
    workspace_mount_set,
    workspace_mount_remove,
    workspace_mount_list,
    workspace_bind_set,
    workspace_bind_remove,
    workspace_bind_list,
    workspace_token_rotate,
    workspace_token_revoke,
    workspace_activate,
    workspace_up,
    workspace_status,
    reconcile_status,
    audit_tail,
    packages_list,
    packages_catalog,
    packages_updates,
    packages_update,
    packages_update_all,
    packages_get,
    packages_channel_get,
    packages_channel_set,
    packages_channel_clear,
    packages_install,
    packages_enable,
    packages_switch,
    packages_disable,
    packages_rollback,
    packages_remove,
    err,
    unknown,
};

pub const FsrpcType = enum {
    t_version,
    r_version,
    t_attach,
    r_attach,
    t_walk,
    r_walk,
    t_open,
    r_open,
    t_read,
    r_read,
    t_write,
    r_write,
    t_stat,
    r_stat,
    t_clunk,
    r_clunk,
    t_flush,
    r_flush,
    fs_t_hello,
    fs_r_hello,
    fs_t_exports,
    fs_r_exports,
    fs_t_lookup,
    fs_r_lookup,
    fs_t_getattr,
    fs_r_getattr,
    fs_t_readdirp,
    fs_r_readdirp,
    fs_t_symlink,
    fs_r_symlink,
    fs_t_setxattr,
    fs_r_setxattr,
    fs_t_getxattr,
    fs_r_getxattr,
    fs_t_listxattr,
    fs_r_listxattr,
    fs_t_removexattr,
    fs_r_removexattr,
    fs_t_open,
    fs_r_open,
    fs_t_read,
    fs_r_read,
    fs_t_close,
    fs_r_close,
    fs_t_lock,
    fs_r_lock,
    fs_t_create,
    fs_r_create,
    fs_t_write,
    fs_r_write,
    fs_t_truncate,
    fs_r_truncate,
    fs_t_unlink,
    fs_r_unlink,
    fs_t_mkdir,
    fs_r_mkdir,
    fs_t_rmdir,
    fs_r_rmdir,
    fs_t_rename,
    fs_r_rename,
    fs_t_statfs,
    fs_r_statfs,
    fs_evt_inval,
    fs_evt_inval_dir,
    fs_err,
    err,
    unknown,
};

pub const ParsedMessage = struct {
    channel: Channel,
    control_type: ?ControlType = null,
    acheron_type: ?FsrpcType = null,

    id: ?[]u8 = null,
    correlation_id: ?[]u8 = null,
    session_key: ?[]u8 = null,
    tag: ?u32 = null,
    node: ?u64 = null,
    handle: ?u64 = null,

    fid: ?u32 = null,
    newfid: ?u32 = null,
    mode: ?[]u8 = null,
    path: [][]u8 = &.{},

    msize: ?u32 = null,
    version: ?[]u8 = null,

    offset: ?u64 = null,
    count: ?u32 = null,
    data: ?[]u8 = null,

    payload_json: ?[]u8 = null,

    pub fn deinit(self: *ParsedMessage, allocator: std.mem.Allocator) void {
        if (self.id) |value| allocator.free(value);
        if (self.correlation_id) |value| allocator.free(value);
        if (self.session_key) |value| allocator.free(value);
        if (self.mode) |value| allocator.free(value);
        if (self.version) |value| allocator.free(value);
        if (self.data) |value| allocator.free(value);
        if (self.payload_json) |value| allocator.free(value);
        for (self.path) |segment| allocator.free(segment);
        if (self.path.len > 0) allocator.free(self.path);
        self.* = undefined;
    }
};

pub fn controlTypeFromString(value: []const u8) ControlType {
    if (std.mem.eql(u8, value, "control.version")) return .version;
    if (std.mem.eql(u8, value, "control.version_ack")) return .version_ack;
    if (std.mem.eql(u8, value, "control.connect")) return .connect;
    if (std.mem.eql(u8, value, "control.connect_ack")) return .connect_ack;
    if (std.mem.eql(u8, value, "control.session_attach")) return .session_attach;
    if (std.mem.eql(u8, value, "control.session_status")) return .session_status;
    if (std.mem.eql(u8, value, "control.mount_attach")) return .mount_attach;
    if (std.mem.eql(u8, value, "control.mount_graph_delta")) return .mount_graph_delta;
    if (std.mem.eql(u8, value, "control.mount_file_read")) return .mount_file_read;
    if (std.mem.eql(u8, value, "control.mount_file_write")) return .mount_file_write;
    if (std.mem.eql(u8, value, "control.mount_path_readlink")) return .mount_path_readlink;
    if (std.mem.eql(u8, value, "control.mount_path_mkdir")) return .mount_path_mkdir;
    if (std.mem.eql(u8, value, "control.mount_path_unlink")) return .mount_path_unlink;
    if (std.mem.eql(u8, value, "control.mount_path_rmdir")) return .mount_path_rmdir;
    if (std.mem.eql(u8, value, "control.mount_path_rename")) return .mount_path_rename;
    if (std.mem.eql(u8, value, "control.mount_path_symlink")) return .mount_path_symlink;
    if (std.mem.eql(u8, value, "control.mount_path_setxattr")) return .mount_path_setxattr;
    if (std.mem.eql(u8, value, "control.mount_path_getxattr")) return .mount_path_getxattr;
    if (std.mem.eql(u8, value, "control.mount_path_listxattr")) return .mount_path_listxattr;
    if (std.mem.eql(u8, value, "control.mount_path_removexattr")) return .mount_path_removexattr;
    if (std.mem.eql(u8, value, "control.mount_path_lock")) return .mount_path_lock;
    if (std.mem.eql(u8, value, "control.mount_path_setattr")) return .mount_path_setattr;
    if (std.mem.eql(u8, value, "control.session_resume")) return .session_resume;
    if (std.mem.eql(u8, value, "control.session_list")) return .session_list;
    if (std.mem.eql(u8, value, "control.session_close")) return .session_close;
    if (std.mem.eql(u8, value, "control.session_restore")) return .session_restore;
    if (std.mem.eql(u8, value, "control.session_history")) return .session_history;
    if (std.mem.eql(u8, value, "control.ping")) return .ping;
    if (std.mem.eql(u8, value, "control.pong")) return .pong;
    if (std.mem.eql(u8, value, "control.metrics")) return .metrics;
    if (std.mem.eql(u8, value, "control.auth_status")) return .auth_status;
    if (std.mem.eql(u8, value, "control.auth_rotate")) return .auth_rotate;
    if (std.mem.eql(u8, value, "control.node_invite_create")) return .node_invite_create;
    if (std.mem.eql(u8, value, "control.node_join_request")) return .node_join_request;
    if (std.mem.eql(u8, value, "control.node_join_pending_list")) return .node_join_pending_list;
    if (std.mem.eql(u8, value, "control.node_join_approve")) return .node_join_approve;
    if (std.mem.eql(u8, value, "control.node_join_deny")) return .node_join_deny;
    if (std.mem.eql(u8, value, "control.node_join")) return .node_join;
    if (std.mem.eql(u8, value, "control.node_ensure")) return .node_ensure;
    if (std.mem.eql(u8, value, "control.node_lease_refresh")) return .node_lease_refresh;
    if (std.mem.eql(u8, value, "control.venom_bind")) return .venom_bind;
    if (std.mem.eql(u8, value, "control.venom_upsert")) return .venom_upsert;
    if (std.mem.eql(u8, value, "control.venom_get")) return .venom_get;
    if (std.mem.eql(u8, value, "control.node_list")) return .node_list;
    if (std.mem.eql(u8, value, "control.node_get")) return .node_get;
    if (std.mem.eql(u8, value, "control.node_delete")) return .node_delete;
    if (std.mem.eql(u8, value, "control.workspace_create")) return .workspace_create;
    if (std.mem.eql(u8, value, "control.workspace_update")) return .workspace_update;
    if (std.mem.eql(u8, value, "control.workspace_delete")) return .workspace_delete;
    if (std.mem.eql(u8, value, "control.workspace_list")) return .workspace_list;
    if (std.mem.eql(u8, value, "control.workspace_get")) return .workspace_get;
    if (std.mem.eql(u8, value, "control.workspace_template_list")) return .workspace_template_list;
    if (std.mem.eql(u8, value, "control.workspace_template_get")) return .workspace_template_get;
    if (std.mem.eql(u8, value, "control.workspace_mount_set")) return .workspace_mount_set;
    if (std.mem.eql(u8, value, "control.workspace_mount_remove")) return .workspace_mount_remove;
    if (std.mem.eql(u8, value, "control.workspace_mount_list")) return .workspace_mount_list;
    if (std.mem.eql(u8, value, "control.workspace_bind_set")) return .workspace_bind_set;
    if (std.mem.eql(u8, value, "control.workspace_bind_remove")) return .workspace_bind_remove;
    if (std.mem.eql(u8, value, "control.workspace_bind_list")) return .workspace_bind_list;
    if (std.mem.eql(u8, value, "control.workspace_token_rotate")) return .workspace_token_rotate;
    if (std.mem.eql(u8, value, "control.workspace_token_revoke")) return .workspace_token_revoke;
    if (std.mem.eql(u8, value, "control.workspace_activate")) return .workspace_activate;
    if (std.mem.eql(u8, value, "control.workspace_up")) return .workspace_up;
    if (std.mem.eql(u8, value, "control.workspace_status")) return .workspace_status;
    if (std.mem.eql(u8, value, "control.reconcile_status")) return .reconcile_status;
    if (std.mem.eql(u8, value, "control.audit_tail")) return .audit_tail;
    if (std.mem.eql(u8, value, "control.packages_list")) return .packages_list;
    if (std.mem.eql(u8, value, "control.packages_catalog")) return .packages_catalog;
    if (std.mem.eql(u8, value, "control.packages_updates")) return .packages_updates;
    if (std.mem.eql(u8, value, "control.packages_update")) return .packages_update;
    if (std.mem.eql(u8, value, "control.packages_update_all")) return .packages_update_all;
    if (std.mem.eql(u8, value, "control.packages_get")) return .packages_get;
    if (std.mem.eql(u8, value, "control.packages_channel_get")) return .packages_channel_get;
    if (std.mem.eql(u8, value, "control.packages_channel_set")) return .packages_channel_set;
    if (std.mem.eql(u8, value, "control.packages_channel_clear")) return .packages_channel_clear;
    if (std.mem.eql(u8, value, "control.packages_install")) return .packages_install;
    if (std.mem.eql(u8, value, "control.packages_enable")) return .packages_enable;
    if (std.mem.eql(u8, value, "control.packages_switch")) return .packages_switch;
    if (std.mem.eql(u8, value, "control.packages_disable")) return .packages_disable;
    if (std.mem.eql(u8, value, "control.packages_rollback")) return .packages_rollback;
    if (std.mem.eql(u8, value, "control.packages_remove")) return .packages_remove;
    if (std.mem.eql(u8, value, "control.error")) return .err;
    return .unknown;
}

pub fn fsrpcTypeFromString(value: []const u8) FsrpcType {
    if (std.mem.eql(u8, value, "acheron.t_version")) return .t_version;
    if (std.mem.eql(u8, value, "acheron.r_version")) return .r_version;
    if (std.mem.eql(u8, value, "acheron.t_attach")) return .t_attach;
    if (std.mem.eql(u8, value, "acheron.r_attach")) return .r_attach;
    if (std.mem.eql(u8, value, "acheron.t_walk")) return .t_walk;
    if (std.mem.eql(u8, value, "acheron.r_walk")) return .r_walk;
    if (std.mem.eql(u8, value, "acheron.t_open")) return .t_open;
    if (std.mem.eql(u8, value, "acheron.r_open")) return .r_open;
    if (std.mem.eql(u8, value, "acheron.t_read")) return .t_read;
    if (std.mem.eql(u8, value, "acheron.r_read")) return .r_read;
    if (std.mem.eql(u8, value, "acheron.t_write")) return .t_write;
    if (std.mem.eql(u8, value, "acheron.r_write")) return .r_write;
    if (std.mem.eql(u8, value, "acheron.t_stat")) return .t_stat;
    if (std.mem.eql(u8, value, "acheron.r_stat")) return .r_stat;
    if (std.mem.eql(u8, value, "acheron.t_clunk")) return .t_clunk;
    if (std.mem.eql(u8, value, "acheron.r_clunk")) return .r_clunk;
    if (std.mem.eql(u8, value, "acheron.t_flush")) return .t_flush;
    if (std.mem.eql(u8, value, "acheron.r_flush")) return .r_flush;
    if (std.mem.eql(u8, value, "acheron.t_fs_hello")) return .fs_t_hello;
    if (std.mem.eql(u8, value, "acheron.r_fs_hello")) return .fs_r_hello;
    if (std.mem.eql(u8, value, "acheron.t_fs_exports")) return .fs_t_exports;
    if (std.mem.eql(u8, value, "acheron.r_fs_exports")) return .fs_r_exports;
    if (std.mem.eql(u8, value, "acheron.t_fs_lookup")) return .fs_t_lookup;
    if (std.mem.eql(u8, value, "acheron.r_fs_lookup")) return .fs_r_lookup;
    if (std.mem.eql(u8, value, "acheron.t_fs_getattr")) return .fs_t_getattr;
    if (std.mem.eql(u8, value, "acheron.r_fs_getattr")) return .fs_r_getattr;
    if (std.mem.eql(u8, value, "acheron.t_fs_readdirp")) return .fs_t_readdirp;
    if (std.mem.eql(u8, value, "acheron.r_fs_readdirp")) return .fs_r_readdirp;
    if (std.mem.eql(u8, value, "acheron.t_fs_symlink")) return .fs_t_symlink;
    if (std.mem.eql(u8, value, "acheron.r_fs_symlink")) return .fs_r_symlink;
    if (std.mem.eql(u8, value, "acheron.t_fs_setxattr")) return .fs_t_setxattr;
    if (std.mem.eql(u8, value, "acheron.r_fs_setxattr")) return .fs_r_setxattr;
    if (std.mem.eql(u8, value, "acheron.t_fs_getxattr")) return .fs_t_getxattr;
    if (std.mem.eql(u8, value, "acheron.r_fs_getxattr")) return .fs_r_getxattr;
    if (std.mem.eql(u8, value, "acheron.t_fs_listxattr")) return .fs_t_listxattr;
    if (std.mem.eql(u8, value, "acheron.r_fs_listxattr")) return .fs_r_listxattr;
    if (std.mem.eql(u8, value, "acheron.t_fs_removexattr")) return .fs_t_removexattr;
    if (std.mem.eql(u8, value, "acheron.r_fs_removexattr")) return .fs_r_removexattr;
    if (std.mem.eql(u8, value, "acheron.t_fs_open")) return .fs_t_open;
    if (std.mem.eql(u8, value, "acheron.r_fs_open")) return .fs_r_open;
    if (std.mem.eql(u8, value, "acheron.t_fs_read")) return .fs_t_read;
    if (std.mem.eql(u8, value, "acheron.r_fs_read")) return .fs_r_read;
    if (std.mem.eql(u8, value, "acheron.t_fs_close")) return .fs_t_close;
    if (std.mem.eql(u8, value, "acheron.r_fs_close")) return .fs_r_close;
    if (std.mem.eql(u8, value, "acheron.t_fs_lock")) return .fs_t_lock;
    if (std.mem.eql(u8, value, "acheron.r_fs_lock")) return .fs_r_lock;
    if (std.mem.eql(u8, value, "acheron.t_fs_create")) return .fs_t_create;
    if (std.mem.eql(u8, value, "acheron.r_fs_create")) return .fs_r_create;
    if (std.mem.eql(u8, value, "acheron.t_fs_write")) return .fs_t_write;
    if (std.mem.eql(u8, value, "acheron.r_fs_write")) return .fs_r_write;
    if (std.mem.eql(u8, value, "acheron.t_fs_truncate")) return .fs_t_truncate;
    if (std.mem.eql(u8, value, "acheron.r_fs_truncate")) return .fs_r_truncate;
    if (std.mem.eql(u8, value, "acheron.t_fs_unlink")) return .fs_t_unlink;
    if (std.mem.eql(u8, value, "acheron.r_fs_unlink")) return .fs_r_unlink;
    if (std.mem.eql(u8, value, "acheron.t_fs_mkdir")) return .fs_t_mkdir;
    if (std.mem.eql(u8, value, "acheron.r_fs_mkdir")) return .fs_r_mkdir;
    if (std.mem.eql(u8, value, "acheron.t_fs_rmdir")) return .fs_t_rmdir;
    if (std.mem.eql(u8, value, "acheron.r_fs_rmdir")) return .fs_r_rmdir;
    if (std.mem.eql(u8, value, "acheron.t_fs_rename")) return .fs_t_rename;
    if (std.mem.eql(u8, value, "acheron.r_fs_rename")) return .fs_r_rename;
    if (std.mem.eql(u8, value, "acheron.t_fs_statfs")) return .fs_t_statfs;
    if (std.mem.eql(u8, value, "acheron.r_fs_statfs")) return .fs_r_statfs;
    if (std.mem.eql(u8, value, "acheron.e_fs_inval")) return .fs_evt_inval;
    if (std.mem.eql(u8, value, "acheron.e_fs_inval_dir")) return .fs_evt_inval_dir;
    if (std.mem.eql(u8, value, "acheron.err_fs")) return .fs_err;
    if (std.mem.eql(u8, value, "acheron.error")) return .err;
    return .unknown;
}

pub const AcheronType = FsrpcType;

pub fn acheronTypeFromString(value: []const u8) FsrpcType {
    return fsrpcTypeFromString(value);
}

pub fn controlTypeName(value: ControlType) []const u8 {
    return switch (value) {
        .version => "control.version",
        .version_ack => "control.version_ack",
        .connect => "control.connect",
        .connect_ack => "control.connect_ack",
        .session_attach => "control.session_attach",
        .session_status => "control.session_status",
        .mount_attach => "control.mount_attach",
        .mount_graph_delta => "control.mount_graph_delta",
        .mount_file_read => "control.mount_file_read",
        .mount_file_write => "control.mount_file_write",
        .mount_path_readlink => "control.mount_path_readlink",
        .mount_path_mkdir => "control.mount_path_mkdir",
        .mount_path_unlink => "control.mount_path_unlink",
        .mount_path_rmdir => "control.mount_path_rmdir",
        .mount_path_rename => "control.mount_path_rename",
        .mount_path_symlink => "control.mount_path_symlink",
        .mount_path_setxattr => "control.mount_path_setxattr",
        .mount_path_getxattr => "control.mount_path_getxattr",
        .mount_path_listxattr => "control.mount_path_listxattr",
        .mount_path_removexattr => "control.mount_path_removexattr",
        .mount_path_lock => "control.mount_path_lock",
        .mount_path_setattr => "control.mount_path_setattr",
        .session_resume => "control.session_resume",
        .session_list => "control.session_list",
        .session_close => "control.session_close",
        .session_restore => "control.session_restore",
        .session_history => "control.session_history",
        .ping => "control.ping",
        .pong => "control.pong",
        .metrics => "control.metrics",
        .auth_status => "control.auth_status",
        .auth_rotate => "control.auth_rotate",
        .node_invite_create => "control.node_invite_create",
        .node_join_request => "control.node_join_request",
        .node_join_pending_list => "control.node_join_pending_list",
        .node_join_approve => "control.node_join_approve",
        .node_join_deny => "control.node_join_deny",
        .node_join => "control.node_join",
        .node_ensure => "control.node_ensure",
        .node_lease_refresh => "control.node_lease_refresh",
        .venom_bind => "control.venom_bind",
        .venom_upsert => "control.venom_upsert",
        .venom_get => "control.venom_get",
        .node_list => "control.node_list",
        .node_get => "control.node_get",
        .node_delete => "control.node_delete",
        .workspace_create => "control.workspace_create",
        .workspace_update => "control.workspace_update",
        .workspace_delete => "control.workspace_delete",
        .workspace_list => "control.workspace_list",
        .workspace_get => "control.workspace_get",
        .workspace_template_list => "control.workspace_template_list",
        .workspace_template_get => "control.workspace_template_get",
        .workspace_mount_set => "control.workspace_mount_set",
        .workspace_mount_remove => "control.workspace_mount_remove",
        .workspace_mount_list => "control.workspace_mount_list",
        .workspace_bind_set => "control.workspace_bind_set",
        .workspace_bind_remove => "control.workspace_bind_remove",
        .workspace_bind_list => "control.workspace_bind_list",
        .workspace_token_rotate => "control.workspace_token_rotate",
        .workspace_token_revoke => "control.workspace_token_revoke",
        .workspace_activate => "control.workspace_activate",
        .workspace_up => "control.workspace_up",
        .workspace_status => "control.workspace_status",
        .reconcile_status => "control.reconcile_status",
        .audit_tail => "control.audit_tail",
        .packages_list => "control.packages_list",
        .packages_catalog => "control.packages_catalog",
        .packages_updates => "control.packages_updates",
        .packages_update => "control.packages_update",
        .packages_update_all => "control.packages_update_all",
        .packages_get => "control.packages_get",
        .packages_channel_get => "control.packages_channel_get",
        .packages_channel_set => "control.packages_channel_set",
        .packages_channel_clear => "control.packages_channel_clear",
        .packages_install => "control.packages_install",
        .packages_enable => "control.packages_enable",
        .packages_switch => "control.packages_switch",
        .packages_disable => "control.packages_disable",
        .packages_rollback => "control.packages_rollback",
        .packages_remove => "control.packages_remove",
        .err => "control.error",
        .unknown => "control.unknown",
    };
}

pub fn fsrpcTypeName(value: FsrpcType) []const u8 {
    return switch (value) {
        .t_version => "acheron.t_version",
        .r_version => "acheron.r_version",
        .t_attach => "acheron.t_attach",
        .r_attach => "acheron.r_attach",
        .t_walk => "acheron.t_walk",
        .r_walk => "acheron.r_walk",
        .t_open => "acheron.t_open",
        .r_open => "acheron.r_open",
        .t_read => "acheron.t_read",
        .r_read => "acheron.r_read",
        .t_write => "acheron.t_write",
        .r_write => "acheron.r_write",
        .t_stat => "acheron.t_stat",
        .r_stat => "acheron.r_stat",
        .t_clunk => "acheron.t_clunk",
        .r_clunk => "acheron.r_clunk",
        .t_flush => "acheron.t_flush",
        .r_flush => "acheron.r_flush",
        .fs_t_hello => "acheron.t_fs_hello",
        .fs_r_hello => "acheron.r_fs_hello",
        .fs_t_exports => "acheron.t_fs_exports",
        .fs_r_exports => "acheron.r_fs_exports",
        .fs_t_lookup => "acheron.t_fs_lookup",
        .fs_r_lookup => "acheron.r_fs_lookup",
        .fs_t_getattr => "acheron.t_fs_getattr",
        .fs_r_getattr => "acheron.r_fs_getattr",
        .fs_t_readdirp => "acheron.t_fs_readdirp",
        .fs_r_readdirp => "acheron.r_fs_readdirp",
        .fs_t_symlink => "acheron.t_fs_symlink",
        .fs_r_symlink => "acheron.r_fs_symlink",
        .fs_t_setxattr => "acheron.t_fs_setxattr",
        .fs_r_setxattr => "acheron.r_fs_setxattr",
        .fs_t_getxattr => "acheron.t_fs_getxattr",
        .fs_r_getxattr => "acheron.r_fs_getxattr",
        .fs_t_listxattr => "acheron.t_fs_listxattr",
        .fs_r_listxattr => "acheron.r_fs_listxattr",
        .fs_t_removexattr => "acheron.t_fs_removexattr",
        .fs_r_removexattr => "acheron.r_fs_removexattr",
        .fs_t_open => "acheron.t_fs_open",
        .fs_r_open => "acheron.r_fs_open",
        .fs_t_read => "acheron.t_fs_read",
        .fs_r_read => "acheron.r_fs_read",
        .fs_t_close => "acheron.t_fs_close",
        .fs_r_close => "acheron.r_fs_close",
        .fs_t_lock => "acheron.t_fs_lock",
        .fs_r_lock => "acheron.r_fs_lock",
        .fs_t_create => "acheron.t_fs_create",
        .fs_r_create => "acheron.r_fs_create",
        .fs_t_write => "acheron.t_fs_write",
        .fs_r_write => "acheron.r_fs_write",
        .fs_t_truncate => "acheron.t_fs_truncate",
        .fs_r_truncate => "acheron.r_fs_truncate",
        .fs_t_unlink => "acheron.t_fs_unlink",
        .fs_r_unlink => "acheron.r_fs_unlink",
        .fs_t_mkdir => "acheron.t_fs_mkdir",
        .fs_r_mkdir => "acheron.r_fs_mkdir",
        .fs_t_rmdir => "acheron.t_fs_rmdir",
        .fs_r_rmdir => "acheron.r_fs_rmdir",
        .fs_t_rename => "acheron.t_fs_rename",
        .fs_r_rename => "acheron.r_fs_rename",
        .fs_t_statfs => "acheron.t_fs_statfs",
        .fs_r_statfs => "acheron.r_fs_statfs",
        .fs_evt_inval => "acheron.e_fs_inval",
        .fs_evt_inval_dir => "acheron.e_fs_inval_dir",
        .fs_err => "acheron.err_fs",
        .err => "acheron.error",
        .unknown => "acheron.unknown",
    };
}

pub fn acheronTypeName(value: FsrpcType) []const u8 {
    return fsrpcTypeName(value);
}

test "unified_types: mount control names round-trip as canonical strings" {
    try std.testing.expectEqual(ControlType.version, controlTypeFromString(controlTypeName(.version)));
    try std.testing.expectEqual(ControlType.connect, controlTypeFromString(controlTypeName(.connect)));
    try std.testing.expectEqual(ControlType.session_attach, controlTypeFromString(controlTypeName(.session_attach)));
    try std.testing.expectEqual(ControlType.session_status, controlTypeFromString(controlTypeName(.session_status)));
    try std.testing.expectEqual(ControlType.mount_attach, controlTypeFromString(controlTypeName(.mount_attach)));
    try std.testing.expectEqual(ControlType.mount_graph_delta, controlTypeFromString(controlTypeName(.mount_graph_delta)));
    try std.testing.expectEqual(ControlType.mount_file_read, controlTypeFromString(controlTypeName(.mount_file_read)));
    try std.testing.expectEqual(ControlType.mount_file_write, controlTypeFromString(controlTypeName(.mount_file_write)));
    try std.testing.expectEqual(ControlType.mount_path_readlink, controlTypeFromString(controlTypeName(.mount_path_readlink)));
    try std.testing.expectEqual(ControlType.mount_path_mkdir, controlTypeFromString(controlTypeName(.mount_path_mkdir)));
    try std.testing.expectEqual(ControlType.mount_path_unlink, controlTypeFromString(controlTypeName(.mount_path_unlink)));
    try std.testing.expectEqual(ControlType.mount_path_rmdir, controlTypeFromString(controlTypeName(.mount_path_rmdir)));
    try std.testing.expectEqual(ControlType.mount_path_rename, controlTypeFromString(controlTypeName(.mount_path_rename)));
    try std.testing.expectEqual(ControlType.mount_path_symlink, controlTypeFromString(controlTypeName(.mount_path_symlink)));
    try std.testing.expectEqual(ControlType.mount_path_setxattr, controlTypeFromString(controlTypeName(.mount_path_setxattr)));
    try std.testing.expectEqual(ControlType.mount_path_getxattr, controlTypeFromString(controlTypeName(.mount_path_getxattr)));
    try std.testing.expectEqual(ControlType.mount_path_listxattr, controlTypeFromString(controlTypeName(.mount_path_listxattr)));
    try std.testing.expectEqual(ControlType.mount_path_removexattr, controlTypeFromString(controlTypeName(.mount_path_removexattr)));
    try std.testing.expectEqual(ControlType.mount_path_lock, controlTypeFromString(controlTypeName(.mount_path_lock)));
    try std.testing.expectEqual(ControlType.mount_path_setattr, controlTypeFromString(controlTypeName(.mount_path_setattr)));
    try std.testing.expectEqual(ControlType.session_restore, controlTypeFromString(controlTypeName(.session_restore)));
    try std.testing.expectEqual(ControlType.session_history, controlTypeFromString(controlTypeName(.session_history)));
    try std.testing.expectEqual(ControlType.node_join_request, controlTypeFromString(controlTypeName(.node_join_request)));
    try std.testing.expectEqual(ControlType.node_join_approve, controlTypeFromString(controlTypeName(.node_join_approve)));
    try std.testing.expectEqual(ControlType.node_ensure, controlTypeFromString(controlTypeName(.node_ensure)));
    try std.testing.expectEqual(ControlType.venom_bind, controlTypeFromString(controlTypeName(.venom_bind)));
    try std.testing.expectEqual(ControlType.venom_upsert, controlTypeFromString(controlTypeName(.venom_upsert)));
    try std.testing.expectEqual(ControlType.venom_get, controlTypeFromString(controlTypeName(.venom_get)));
    try std.testing.expectEqual(ControlType.workspace_create, controlTypeFromString(controlTypeName(.workspace_create)));
    try std.testing.expectEqual(ControlType.workspace_template_list, controlTypeFromString(controlTypeName(.workspace_template_list)));
    try std.testing.expectEqual(ControlType.workspace_template_get, controlTypeFromString(controlTypeName(.workspace_template_get)));
    try std.testing.expectEqual(ControlType.workspace_mount_set, controlTypeFromString(controlTypeName(.workspace_mount_set)));
    try std.testing.expectEqual(ControlType.workspace_bind_set, controlTypeFromString(controlTypeName(.workspace_bind_set)));
    try std.testing.expectEqual(ControlType.workspace_bind_remove, controlTypeFromString(controlTypeName(.workspace_bind_remove)));
    try std.testing.expectEqual(ControlType.workspace_bind_list, controlTypeFromString(controlTypeName(.workspace_bind_list)));
    try std.testing.expectEqual(ControlType.workspace_up, controlTypeFromString(controlTypeName(.workspace_up)));
    try std.testing.expectEqual(ControlType.workspace_status, controlTypeFromString(controlTypeName(.workspace_status)));
    try std.testing.expectEqual(ControlType.reconcile_status, controlTypeFromString(controlTypeName(.reconcile_status)));
    try std.testing.expectEqual(ControlType.audit_tail, controlTypeFromString(controlTypeName(.audit_tail)));
    try std.testing.expectEqual(ControlType.packages_list, controlTypeFromString(controlTypeName(.packages_list)));
    try std.testing.expectEqual(ControlType.packages_catalog, controlTypeFromString(controlTypeName(.packages_catalog)));
    try std.testing.expectEqual(ControlType.packages_updates, controlTypeFromString(controlTypeName(.packages_updates)));
    try std.testing.expectEqual(ControlType.packages_update, controlTypeFromString(controlTypeName(.packages_update)));
    try std.testing.expectEqual(ControlType.packages_update_all, controlTypeFromString(controlTypeName(.packages_update_all)));
    try std.testing.expectEqual(ControlType.packages_get, controlTypeFromString(controlTypeName(.packages_get)));
    try std.testing.expectEqual(ControlType.packages_channel_get, controlTypeFromString(controlTypeName(.packages_channel_get)));
    try std.testing.expectEqual(ControlType.packages_channel_set, controlTypeFromString(controlTypeName(.packages_channel_set)));
    try std.testing.expectEqual(ControlType.packages_channel_clear, controlTypeFromString(controlTypeName(.packages_channel_clear)));
    try std.testing.expectEqual(ControlType.packages_install, controlTypeFromString(controlTypeName(.packages_install)));
    try std.testing.expectEqual(ControlType.packages_enable, controlTypeFromString(controlTypeName(.packages_enable)));
    try std.testing.expectEqual(ControlType.packages_switch, controlTypeFromString(controlTypeName(.packages_switch)));
    try std.testing.expectEqual(ControlType.packages_disable, controlTypeFromString(controlTypeName(.packages_disable)));
    try std.testing.expectEqual(ControlType.packages_rollback, controlTypeFromString(controlTypeName(.packages_rollback)));
    try std.testing.expectEqual(ControlType.packages_remove, controlTypeFromString(controlTypeName(.packages_remove)));
    try std.testing.expectEqual(ControlType.err, controlTypeFromString(controlTypeName(.err)));
}

test "unified_types: fsrpc names round-trip as canonical strings" {
    try std.testing.expectEqual(FsrpcType.t_version, fsrpcTypeFromString(fsrpcTypeName(.t_version)));
    try std.testing.expectEqual(FsrpcType.fs_t_hello, fsrpcTypeFromString(fsrpcTypeName(.fs_t_hello)));
    try std.testing.expectEqual(FsrpcType.fs_t_readdirp, fsrpcTypeFromString(fsrpcTypeName(.fs_t_readdirp)));
    try std.testing.expectEqual(FsrpcType.fs_evt_inval, fsrpcTypeFromString(fsrpcTypeName(.fs_evt_inval)));
    try std.testing.expectEqual(FsrpcType.err, fsrpcTypeFromString(fsrpcTypeName(.err)));
}

test "unified_types: fsrpc canonical names are unique and exhaustive" {
    const allocator = std.testing.allocator;
    var seen = std.StringHashMapUnmanaged(FsrpcType){};
    defer seen.deinit(allocator);

    inline for (std.meta.fields(FsrpcType)) |field| {
        const value: FsrpcType = @enumFromInt(field.value);
        if (value == .unknown) continue;

        const wire_name = fsrpcTypeName(value);
        const existing = try seen.getOrPut(allocator, wire_name);
        if (existing.found_existing) {
            std.debug.print(
                "duplicate FsrpcType wire name '{s}' for {s} and {s}\n",
                .{ wire_name, @tagName(existing.value_ptr.*), @tagName(value) },
            );
        }
        try std.testing.expect(!existing.found_existing);
        existing.value_ptr.* = value;

        try std.testing.expectEqual(value, fsrpcTypeFromString(wire_name));
    }

    try std.testing.expectEqualStrings("acheron.t_open", fsrpcTypeName(.t_open));
    try std.testing.expectEqualStrings("acheron.t_fs_open", fsrpcTypeName(.fs_t_open));
    try std.testing.expectEqualStrings("acheron.t_read", fsrpcTypeName(.t_read));
    try std.testing.expectEqualStrings("acheron.t_fs_read", fsrpcTypeName(.fs_t_read));
    try std.testing.expectEqualStrings("acheron.t_write", fsrpcTypeName(.t_write));
    try std.testing.expectEqualStrings("acheron.t_fs_write", fsrpcTypeName(.fs_t_write));
}

test "unified_types: legacy message names are not recognized" {
    try std.testing.expectEqual(ControlType.unknown, controlTypeFromString("session.send"));
    try std.testing.expectEqual(ControlType.unknown, controlTypeFromString("control.debug_subscribe"));
    try std.testing.expectEqual(ControlType.unknown, controlTypeFromString("control.debug_unsubscribe"));
    try std.testing.expectEqual(ControlType.unknown, controlTypeFromString("control.node_service_watch"));
    try std.testing.expectEqual(ControlType.unknown, controlTypeFromString("control.node_service_unwatch"));
    try std.testing.expectEqual(ControlType.unknown, controlTypeFromString("control.node_service_event"));
    try std.testing.expectEqual(FsrpcType.unknown, fsrpcTypeFromString("acheron.t_hello"));
}
