const std = @import("std");

test leftPad {
    var t1 = leftPad("hello", 3, '.');
    defer t1.cleanup();

    try std.testing.expectEqualStrings("...hello", t1.getData());
}

pub fn leftPad(str: []const u8, len: usize, ch: u8) LeftPadOutData {
    var lpc = LeftPadConstructor.new();

    const create_msg = LeftPadMessageHandler.init(LeftPadMessage.initCreate(str, len, ch));
    create_msg.sendTo(&lpc);

    const exec_msg = LeftPadMessageHandler.init(LeftPadMessage.initExecute(lpc.getExecuteOut()));
    exec_msg.sendTo(&lpc);

    return LeftPadOutData{ .data = lpc.getData() };
}

const LeftPadOutData = struct {
    data: []const u8,

    pub fn cleanup(self: LeftPadOutData) void {
        std.heap.page_allocator.free(self.data);
    }

    pub fn getData(self: LeftPadOutData) []const u8 {
        return self.data;
    }
};

const LeftPadConstructor = struct {
    data_manager: LeftPadDataManager,
    data_executor: LeftPadDataExecutor,

    fn new() LeftPadConstructor {
        var lpc: LeftPadConstructor = undefined;
        LeftPadDataManagerFactory.instance.create(&lpc);
        lpc.data_executor = .{};
        return lpc;
    }

    fn execute(self: *LeftPadConstructor) void {
        self.data_manager.shiftTextRight();
    }

    fn getDataExecutor(self: *LeftPadConstructor) *LeftPadDataExecutor {
        return &self.data_executor;
    }

    fn getDataManager(self: *LeftPadConstructor) *LeftPadDataManager {
        return &self.data_manager;
    }

    fn setDataManager(self: *LeftPadConstructor, data_manager: LeftPadDataManager) void {
        self.data_manager = data_manager;
    }

    fn getExecuteOut(self: *LeftPadConstructor) *[]const u8 {
        return &self.data_manager.str;
    }

    fn getData(self: LeftPadConstructor) []const u8 {
        return self.data_manager.getData();
    }
};

const LeftPadMessageHandler = struct {
    msg: LeftPadMessage,

    pub fn init(msg: LeftPadMessage) LeftPadMessageHandler {
        return .{ .msg = msg };
    }

    pub fn sendTo(self: LeftPadMessageHandler, constructor: *LeftPadConstructor) void {
        if (std.mem.eql(u8, self.msg.my_message_type, "create")) {
            constructor.getDataManager().populate(self.msg.create.str, self.msg.create.len, self.msg.create.ch);
        } else if (std.mem.eql(u8, self.msg.my_message_type, "execute")) {
            self.msg.execute.data_destination.* = constructor.getDataExecutor().execute(constructor.getDataManager().*);
        } else {
            @panic("Unrecognized message!!!");
        }
    }
};

const LeftPadMessage = struct {
    my_message_type: []const u8,
    create: struct {
        str: []const u8,
        len: usize,
        ch: u8,
    },
    execute: struct {
        data_destination: *[]const u8,
    },

    pub fn initCreate(str: []const u8, len: usize, ch: u8) LeftPadMessage {
        return .{
            .my_message_type = "create",
            .create = .{
                .str = str,
                .len = len,
                .ch = ch,
            },
            .execute = undefined,
        };
    }

    pub fn initExecute(data_destination: *[]const u8) LeftPadMessage {
        return .{
            .my_message_type = "execute",
            .create = undefined,
            .execute = .{
                .data_destination = data_destination,
            },
        };
    }
};

const LeftPadDataManager = struct {
    str: []const u8,
    len: usize,
    ch: u8,

    pub fn cleanup(self: LeftPadDataManager) void {
        std.heap.page_allocator.free(self.str);
    }

    pub fn populate(self: *LeftPadDataManager, str: []const u8, len: usize, ch: u8) void {
        self.str = str;
        self.len = len;
        self.ch = ch;
    }

    pub fn getData(self: LeftPadDataManager) []const u8 {
        return self.str;
    }

    pub fn calculatePadLength(self: LeftPadDataManager) usize {
        return self.str.len + self.len;
    }

    pub fn foreachInStr(self: LeftPadDataManager, context: anytype) void {
        var iter = StringIterator{ .str = self.str };
        iter.foreach(context);
    }
};

const LeftPadDataManagerFactory = struct {
    var instance: LeftPadDataManagerFactory = .{};

    pub fn create(_: LeftPadDataManagerFactory, constructor: *LeftPadConstructor) void {
        constructor.setDataManager(LeftPadDataManager{
            .str = &.{},
            .len = 0,
            .ch = 0,
        });
    }
};

const LeftPadDataExecutor = struct {
    pub fn execute(_: LeftPadDataExecutor, data: LeftPadDataManager) []const u8 {
        const prefix = LeftPadPrefix.create(data);
        defer prefix.destroy();

        const result = combinePrefixAndText(data, prefix.getPrefixData());
        return result;
    }

    fn combinePrefixAndText(data: LeftPadDataManager, prefix: []const u8) []const u8 {
        var final_text = std.ArrayList(u8).init(std.heap.page_allocator);
        defer final_text.deinit();

        const PrefixContext = struct {
            final_text_arr: *std.ArrayList(u8),

            pub fn exec(self: @This(), char: u8) void {
                self.final_text_arr.append(char) catch {};
            }
        };
        var iter = StringIterator{ .str = prefix };
        iter.foreach(PrefixContext{ .final_text_arr = &final_text });

        const PostfixContext = struct {
            final_text_arr: *std.ArrayList(u8),

            pub fn exec(self: @This(), char: u8) void {
                self.final_text_arr.append(char) catch {};
            }
        };
        data.foreachInStr(PostfixContext{ .final_text_arr = &final_text });

        return final_text.toOwnedSlice() catch "CANT CONVERT TO OWNED";
    }
};

const LeftPadPrefix = struct {
    prefix: []const u8,

    pub fn create(data: LeftPadDataManager) LeftPadPrefix {
        return .{
            .prefix = createPrefixStr(data),
        };
    }

    pub fn destroy(self: LeftPadPrefix) void {
        std.heap.page_allocator.free(self.prefix);
    }

    pub fn getPrefixData(self: LeftPadPrefix) []const u8 {
        return self.prefix;
    }

    fn createPrefixStr(data: LeftPadDataManager) []const u8 {
        var prefix_list = std.ArrayList([]const u8).init(std.heap.page_allocator);
        defer prefix_list.deinit();

        for (0..data.len) |_| {
            var prefix_buf = std.heap.page_allocator.alloc(u8, 1) catch return "CANT ALLOCATE DATA";
            prefix_buf[0] = data.ch;
            prefix_list.append(prefix_buf) catch return "CANT APPEND DATA";
        }
        defer for (prefix_list.items) |p| {
            std.heap.page_allocator.free(p);
        };

        var finished_prefix = std.ArrayList(u8).init(std.heap.page_allocator);
        defer finished_prefix.deinit();

        for (prefix_list.items) |p| {
            const FinishedPrefixAppendContext = struct {
                finished_prefix_arr: *std.ArrayList(u8),

                pub fn exec(self: @This(), char: u8) void {
                    self.finished_prefix_arr.append(char) catch {};
                }
            };

            var iter = StringIterator{ .str = p };
            iter.foreach(FinishedPrefixAppendContext{ .finished_prefix_arr = &finished_prefix });
        }

        return finished_prefix.toOwnedSlice() catch return "CANT CONVERT TO OWNED";
    }
};

const StringIterator = struct {
    str: []const u8,

    pub fn foreach(self: StringIterator, context: anytype) void {
        for (self.str) |c| context.exec(c);
    }
};
