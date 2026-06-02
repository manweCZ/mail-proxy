# Mail Proxy API Documentation

**Base URL:** `https://mailproxy.biteit.cz/api/v1`

This API accepts email jobs and delivers them via a configured SMTP relay with rate limiting, retry logic, and optional webhook callbacks.

---

## Authentication

All endpoints require a Bearer token in the `Authorization` header.

```
Authorization: Bearer <your_token>
```

If the token is missing or invalid, the API returns:

```
HTTP 401 Unauthorized
{"error": "unauthorized"}
```

---

## Endpoints

### POST /email

Queue an email for delivery. The API returns immediately with a job ID; delivery happens asynchronously.

**URL:** `https://mailproxy.biteit.cz/api/v1/email`

**Method:** `POST`

**Content-Type:** `application/json`

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `to` | array of strings | Yes | Recipient email addresses (at least 1 required) |
| `subject` | string | Yes | Email subject line |
| `body` | string | Yes | Email body (HTML supported) |
| `from` | string | No | Sender address; defaults to the account's configured SMTP user |
| `cc` | array of strings | No | CC recipients |
| `bcc` | array of strings | No | BCC recipients |
| `attachments` | array of objects | No | See attachment structure below |

#### Attachment Object

Each attachment **must** have a `filename` and exactly one of `data` or `url`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filename` | string | Yes | Desired filename for the attachment |
| `content_type` | string | No | MIME type (auto-detected from filename if omitted) |
| `data` | string | No* | Base64-encoded file content |
| `url` | string | No* | Public URL to download the file from at send time |

\* Exactly one of `data` or `url` must be provided per attachment.

#### Responses

**Success — HTTP 202 Accepted**

```json
{
  "job_id": 123
}
```

**Validation error — HTTP 422 Unprocessable Entity**

```json
{
  "errors": {
    "to": ["can't be blank"],
    "subject": ["can't be blank"]
  }
}
```

**Attachment validation error — HTTP 422 Unprocessable Entity**

```json
{
  "error": "attachment missing filename"
}
```

```json
{
  "error": "invalid base64 data for attachment document.pdf"
}
```

```json
{
  "error": "attachment document.pdf must have either data or url"
}
```

**Server error — HTTP 500 Internal Server Error**

```json
{
  "status": "error",
  "reason": "<details>"
}
```

---

## Webhooks

If the account is configured with a `webhook_url`, the API will POST a JSON payload to that URL when a job finishes (successfully or after all retries are exhausted).

**Webhook payload:**

```json
{
  "job_id": 123,
  "status": "sent",
  "to": ["recipient@example.com"],
  "attempts": 1
}
```

`status` is either `"sent"` or `"failed"`.

---

## Delivery Behavior

- Jobs are delivered asynchronously after the API responds with 202.
- Rate limiting is applied per account (configured server-side).
- On SMTP failure, jobs are retried up to **3 times** with exponential backoff:
  - After 1st failure: retry after ~120 seconds
  - After 2nd failure: retry after ~240 seconds
  - After 3rd failure: job is marked `failed`, webhook is called
- Jobs stuck in processing for over 5 minutes are automatically re-queued.

---

## PHP Examples

### Send a plain email

```php
<?php

$token = 'your_bearer_token';
$url   = 'https://mailproxy.biteit.cz/api/v1/email';

$payload = [
    'to'      => ['recipient@example.com'],
    'subject' => 'Hello from Mail Proxy',
    'body'    => '<p>This is a test email.</p>',
];

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => json_encode($payload),
    CURLOPT_HTTPHEADER     => [
        'Authorization: Bearer ' . $token,
        'Content-Type: application/json',
        'Accept: application/json',
    ],
]);

$response = curl_exec($ch);
$status   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$data = json_decode($response, true);

if ($status === 202) {
    echo 'Queued job ID: ' . $data['job_id'];
} else {
    echo 'Error ' . $status . ': ' . $response;
}
```

---

### Send with CC, BCC, and a custom From

```php
<?php

$payload = [
    'from'    => 'noreply@yourdomain.com',
    'to'      => ['alice@example.com', 'bob@example.com'],
    'cc'      => ['manager@example.com'],
    'bcc'     => ['audit@example.com'],
    'subject' => 'Monthly Report',
    'body'    => '<h1>Report</h1><p>Please find the report attached.</p>',
];
```

---

### Send with a base64-encoded attachment

```php
<?php

$fileContent = file_get_contents('/path/to/document.pdf');

$payload = [
    'to'      => ['recipient@example.com'],
    'subject' => 'Document attached',
    'body'    => '<p>Please find the document attached.</p>',
    'attachments' => [
        [
            'filename'     => 'document.pdf',
            'content_type' => 'application/pdf',
            'data'         => base64_encode($fileContent),
        ],
    ],
];
```

---

### Send with a URL attachment (file downloaded at send time)

```php
<?php

$payload = [
    'to'      => ['recipient@example.com'],
    'subject' => 'File from URL',
    'body'    => '<p>See the attachment.</p>',
    'attachments' => [
        [
            'filename' => 'report.xlsx',
            'url'      => 'https://yourserver.com/exports/report.xlsx',
        ],
    ],
];
```

---

### Reusable helper class

```php
<?php

class MailProxyClient
{
    private string $baseUrl = 'https://mailproxy.biteit.cz/api/v1';
    private string $token;

    public function __construct(string $token)
    {
        $this->token = $token;
    }

    /**
     * @param array $params {
     *   to: string[],
     *   subject: string,
     *   body: string,
     *   from?: string,
     *   cc?: string[],
     *   bcc?: string[],
     *   attachments?: array
     * }
     * @return array{job_id: int}
     * @throws RuntimeException on HTTP error
     */
    public function send(array $params): array
    {
        $ch = curl_init($this->baseUrl . '/email');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($params),
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $this->token,
                'Content-Type: application/json',
                'Accept: application/json',
            ],
        ]);

        $response = curl_exec($ch);
        $status   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error    = curl_error($ch);
        curl_close($ch);

        if ($error) {
            throw new RuntimeException('cURL error: ' . $error);
        }

        $data = json_decode($response, true);

        if ($status === 202) {
            return $data;
        }

        $message = isset($data['errors'])
            ? json_encode($data['errors'])
            : ($data['error'] ?? $data['reason'] ?? $response);

        throw new RuntimeException('Mail Proxy error ' . $status . ': ' . $message);
    }

    /**
     * Attach a local file by reading and base64-encoding it.
     */
    public function attachFile(string $path, ?string $filename = null, ?string $contentType = null): array
    {
        return [
            'filename'     => $filename ?? basename($path),
            'content_type' => $contentType ?? mime_content_type($path),
            'data'         => base64_encode(file_get_contents($path)),
        ];
    }
}

// Usage:
$client = new MailProxyClient('your_bearer_token');

$jobId = $client->send([
    'to'          => ['recipient@example.com'],
    'subject'     => 'Hello',
    'body'        => '<p>Hi there!</p>',
    'attachments' => [
        $client->attachFile('/path/to/invoice.pdf'),
    ],
])['job_id'];

echo 'Queued as job ' . $jobId;
```

---

## Error Reference

| HTTP Status | Meaning |
|------------|---------|
| 202 | Job accepted and queued for delivery |
| 401 | Invalid or missing Bearer token |
| 422 | Request validation failed (see `errors` or `error` field in response) |
| 500 | Internal server error |

Common 422 error messages:

| Error | Cause |
|-------|-------|
| `"to can't be blank"` | `to` field missing or empty array |
| `"subject can't be blank"` | `subject` field missing |
| `"body can't be blank"` | `body` field missing |
| `"attachment missing filename"` | Attachment object has no `filename` |
| `"invalid base64 data for attachment <filename>"` | `data` field is not valid base64 |
| `"attachment <filename> must have either data or url"` | Attachment has neither `data` nor `url`, or has both |
