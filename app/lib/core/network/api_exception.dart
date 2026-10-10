sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NoConnectionException extends ApiException {
  const NoConnectionException() : super('Sin conexion a internet');
}

class RequestTimeoutException extends ApiException {
  const RequestTimeoutException() : super('El servidor tardo demasiado en responder');
}

class HttpStatusException extends ApiException {
  const HttpStatusException(this.statusCode)
      : super('El servidor respondio con error $statusCode');

  final int statusCode;
}

class InvalidResponseException extends ApiException {
  const InvalidResponseException() : super('La respuesta del servidor no es valida');
}