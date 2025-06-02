# Running

1. clone the repo
```sh
git clone https://github.com/not-a-cowfr/water.zig.git
```
2. update the fingerprint
```sh
./fingerprint
```
3. run the project
```sh
zig build run
```

# Events

### Creating an event listener
since afaik zig doesnt have events built in, im using comments and a custom prebuild code gen to make events work
```zig
const events = @import("events.zig");

// @EventHandler(<event type>)
pub fn event_handler_thingy(e: events.Event) void {
    const event = e.<event type>;
}
```

make sure that

1. the event listener returns `void`, no errors and no values may be returned
2. make sure the function takes in a Event paremeter as seen in the example
3. make sure the event type is a valid enum variant

### Creating a new event type

add the new type to the EventType enum in [events.zig](./src/events.zig)

```zig
pub const EventType = enum {
    // ...
    NewEvent,
};
```

then add the event data to the Event struct

```zig
pub const Event = union(EventType) {
    // ...
    NewEvent: struct {
        // ...
    },
};
```

### Posting an event

```zig
const event = events.Event{ .<event type> = .{ <event type data> } };
dispatcher.post(event, events.EventType.<event type>);
```