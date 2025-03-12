MODULE_NAME='mEventScheduler'   (
                                    dev vdvObject
                                )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.DateTimeUtils.axi'
#include 'NAVFoundation.TimelineUtils.axi'
#include 'NAVFoundation.ErrorLogUtils.axi'
#include 'NAVFoundation.StringUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_EVENT_LOOP = 1

constant integer MAX_EVENTS = 20

constant char DEFAULT_SHUT_DOWN_TIME[] = '22:00'


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

struct _Event {
    char Name[NAV_MAX_CHARS]
    _NAVTimespec Timespec
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long eventLoop[] = { 500 }

volatile _Event events[MAX_EVENTS]
volatile integer eventCount = 0


(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function TriggerEvent(_Event event) {
    NAVErrorLog(NAV_LOG_LEVEL_INFO, "'Event triggered => ', event.Name")
    send_string vdvObject, "'EVENT_TRIGGERED-', event.Name"
}


define_function HandleEvents(ttimeline timeline) {
    stack_var _NAVTimespec timespec
    stack_var integer x

    NAVDateTimeGetTimespecNow(timespec)

    for (x = 1; x <= eventCount; x++) {
        if (!length_array(events[x].Name)) {
            continue
        }

        if (!NAVDateTimeTimespecTimeIsMatch(timespec, events[x].Timespec)) {
            continue
        }

        TriggerEvent(events[x])
    }
}


define_function char NAVDateTimeTimespecTimeIsMatch(_NAVTimespec now, _NAVTimespec event) {
    return (now.Hour == event.Hour && now.Minute == event.Minute && now.Seconds == event.Seconds)
}


define_function sinteger NAVDateTimeGetTimespecFromTime(char time[], _NAVTimespec timespec) {
    stack_var char sections[3][2]
    stack_var integer count

    count = NAVSplitString(time, ':', sections)

    if (count < 2) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, 'NAVDateTimeGetTimespecFromTime: Invalid time format')
        return -1
    }

    timespec.Hour = atoi(sections[1])
    timespec.Minute = atoi(sections[2])
    timespec.Seconds = 0

    return 0
}


define_function AddEvent(char name[], char time[]) {
    stack_var _Event event
    stack_var sinteger result

    if (!length_array(name)) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, 'AddEvent: Invalid name')
        return
    }

    if (!length_array(time)) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, 'AddEvent: Invalid time')
        return
    }

    event.Name = name
    result = NAVDateTimeGetTimespecFromTime(time, event.Timespec)

    if (result < 0) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, 'AddEvent: Invalid time')
        return
    }

    eventCount++
    events[eventCount] = event
}


define_function integer FindEvent(char name[]) {
    stack_var integer x

    for (x = 1; x <= eventCount; x++) {
        if (events[x].Name != name) {
            continue
        }

        return x
    }

    return 0
}


define_function ShuffleEvents(integer start) {
    stack_var integer x

    for (x = start; x < eventCount; x++) {
        events[x].Name = events[x + 1].Name
        events[x].Timespec = events[x + 1].Timespec
    }
}


define_function ClearEvent(_Event event) {
    event.Name = ''
    event.Timespec.Hour = 0
    event.Timespec.Minute = 0
    event.Timespec.Seconds = 0
}


define_function DeleteEvent(char name[]) {
    stack_var integer event

    event = FindEvent(name)

    if (event <= 0) {
        return
    }

    if (event < eventCount) {
        ShuffleEvents(event)
    }
    else {
        ClearEvent(events[event])
    }

    eventCount--
}


define_function UpdateEvent(char name[], char time[]) {
    stack_var integer event
    stack_var sinteger result

    event = FindEvent(name)

    if (event <= 0) {
        return
    }

    result = NAVDateTimeGetTimespecFromTime(time, events[event].Timespec)

    if (result < 0) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, 'UpdateEvent: Invalid time')
        return
    }
}


define_function InitializeEvents() {
    stack_var integer x

    for (x = 1; x <= MAX_EVENTS; x++) {
        ClearEvent(events[x])
    }
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    InitializeEvents()
    NAVTimelineStart(TL_EVENT_LOOP, eventLoop, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT


data_event[vdvObject] {
    online: {

    }
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case 'ADD_EVENT': {
                AddEvent(message.Parameter[1], message.Parameter[2])
            }
            case 'DELETE_EVENT': {
                DeleteEvent(message.Parameter[1])
            }
            case 'UPDATE_EVENT': {
                UpdateEvent(message.Parameter[1], message.Parameter[2])
            }
        }
    }
}


timeline_event[TL_EVENT_LOOP] {
    HandleEvents(timeline)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
