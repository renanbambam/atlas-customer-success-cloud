/**
 * Configurable telemetry API double: happy path, transient failure (5xx),
 * deterministic failure (4xx) and garbage payloads. Counts invocations so
 * retry tests can assert how many attempts actually happened.
 */
@IsTest
public class TelemetryCalloutMock implements HttpCalloutMock {
    public Integer statusCode = 200;
    public String body = '[]';
    public Integer invocationCount = 0;

    public static TelemetryCalloutMock success(List<TelemetryUsageDTO> usages) {
        TelemetryCalloutMock mock = new TelemetryCalloutMock();
        mock.body = JSON.serialize(usages);
        return mock;
    }

    public static TelemetryCalloutMock failing(Integer statusCode) {
        TelemetryCalloutMock mock = new TelemetryCalloutMock();
        mock.statusCode = statusCode;
        mock.body = '{"error":"boom"}';
        return mock;
    }

    public HttpResponse respond(HttpRequest request) {
        invocationCount++;
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(body);
        return response;
    }
}
