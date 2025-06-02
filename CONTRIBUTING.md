# Running

1. close the repo
```sh
git clone https://github.com/not-a-cowfr/water.zig.git
```
2. update the fingerprint

    a. delete the fingerprint in [build.zig.zon](./build.zig.zon)

    b. run the project
    ```sh
    zig build run
    ```
    c. copy the fingerprint in the error and add it to your [build.zig.zon](./build.zig.zon)
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