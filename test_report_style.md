# Automated Test Feedback Loop Design

To enable the AI and CI pipelines to autonomously execute, parse, and fix code, we propose a standardized **Test Report Style** using Flutter's JSON reporter. 

---

## 1. Triggering Tests

To get a parseable stream of test events, execute tests with the `--reporter=json` flag:

```bash
flutter test --reporter=json
```

---

## 2. JSON Event Schema

The JSON reporter outputs a stream of line-delimited JSON objects. Below are the key events our parser monitors to map errors to code locations:

### A. Test Registration (`testStart`)
Emitted when a test is registered. Maps a unique numerical ID (`id`) to the test name and source path.

```json
{
  "type": "testStart",
  "test": {
    "id": 14,
    "name": "MockRcloneService Tests addRemote throws exception if remote already exists",
    "suiteID": 1,
    "url": "file:///D:/code%20gemini/fibu%20win/test/unit/rclone_service_test.dart",
    "line": 31,
    "column": 5
  },
  "time": 128
}
```

### B. Error Capture (`error`)
Emitted when a test fails. Contains the exact stack trace and failure assertion messages.

```json
{
  "type": "error",
  "testID": 14,
  "error": "Expected: throws <Exception>\n  Actual: <Closure: () => Future<void>>\n          which returned a Future that completed successfully",
  "stackTrace": "package:test_api/src/backend/declarer.dart 220:19  Declarer.test.<fn>\n...",
  "isFailure": true,
  "time": 250
}
```

### C. Test Completion (`testDone`)
Indicates if the test passed, failed, or was skipped.

```json
{
  "type": "testDone",
  "testID": 14,
  "result": "error", // 'success', 'error', or 'hidden'
  "hidden": false,
  "time": 255
}
```

---

## 3. Parser Algorithm for AI Feedback Loop

The AI helper script processes this stream to build a structured failure report. The pseudo-logic is:

```python
failures = {}
tests = {}

for line in test_stdout:
    event = json.loads(line)
    
    if event["type"] == "testStart":
        tests[event["test"]["id"]] = event["test"]
        
    elif event["type"] == "error":
        tid = event["testID"]
        if tid not in failures:
            failures[tid] = []
        failures[tid].append({
            "message": event["error"],
            "stackTrace": event["stackTrace"]
        })
        
    elif event["type"] == "testDone" and event["result"] == "error":
        tid = event["testID"]
        test_info = tests[tid]
        print(f"❌ FAIL: {test_info['name']}")
        print(f"📍 Location: {test_info['url']}:{test_info['line']}:{test_info['column']}")
        for err in failures[tid]:
            print(f"⚠️ Error: {err['message']}")
```

---

## 4. Autonomous Fix Strategy

When a test failure is parsed, the AI will:
1. Scan the test `url` and `line` to understand the assertion.
2. Trace the class under test (e.g. `RcloneService`) in the project directory using `grep_search`.
3. Locate the error context, generate a patch, and run the test suite again.
4. Verify the exit code returns `0` before proceeding to the next phase.
