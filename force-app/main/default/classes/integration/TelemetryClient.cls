/**
 * HTTP client for the telemetry API. Endpoint and credentials come from the
 * Telemetry_API named credential; timeout comes from Atlas_Setting__mdt.
 *
 * The client never throws across the boundary: callers get a Result that
 * says whether the failure is worth retrying (5xx, timeout) or deterministic
 * (4xx), because that decision belongs to the retry policy, not the caller's
 * exception handler.
 */
public inherited sharing class TelemetryClient {
    public Result fetchUsage(List<String> accountKeys) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:Telemetry_API/usage?accounts=' +
            EncodingUtil.urlEncode(String.join(accountKeys, ','), 'UTF-8')
        );
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(AtlasSettings.calloutTimeoutMs());

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (System.CalloutException e) {
            // Timeouts and connection resets are transient by definition.
            return retryableFailure('Callout failed: ' + e.getMessage());
        }

        Integer status = response.getStatusCode();
        if (status >= 200 && status < 300) {
            try {
                List<TelemetryUsageDTO> usages = (List<TelemetryUsageDTO>) JSON.deserialize(
                    response.getBody(),
                    List<TelemetryUsageDTO>.class
                );
                return successResult(usages);
            } catch (System.JSONException e) {
                // A malformed body will be malformed on retry too.
                return permanentFailure('Unparseable telemetry payload: ' + e.getMessage());
            }
        }
        if (status >= 500) {
            return retryableFailure('Telemetry API returned ' + status);
        }
        return permanentFailure('Telemetry API returned ' + status + ': ' + response.getBody());
    }

    // Factories live on the outer class: Apex inner classes cannot declare
    // static methods.
    private static Result successResult(List<TelemetryUsageDTO> usages) {
        Result result = new Result();
        result.success = true;
        result.usages = usages == null ? new List<TelemetryUsageDTO>() : usages;
        return result;
    }

    private static Result retryableFailure(String error) {
        Result result = new Result();
        result.retryable = true;
        result.error = error;
        return result;
    }

    private static Result permanentFailure(String error) {
        Result result = new Result();
        result.error = error;
        return result;
    }

    public class Result {
        public Boolean success = false;
        public Boolean retryable = false;
        public String error;
        public List<TelemetryUsageDTO> usages = new List<TelemetryUsageDTO>();
    }
}
