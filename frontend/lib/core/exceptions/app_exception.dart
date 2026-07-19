class AppException implements Exception {
  const AppException({required this.message, this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException({required super.message})
      : super(code: 'NETWORK_ERROR');
}

class TimeoutException extends AppException {
  const TimeoutException()
      : super(message: 'Request timed out. Please try again.', code: 'TIMEOUT');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException()
      : super(
            message: 'Session expired. Please log in again.',
            statusCode: 401,
            code: 'UNAUTHORIZED');
}

class NotFoundException extends AppException {
  const NotFoundException({required super.message})
      : super(statusCode: 404, code: 'NOT_FOUND');
}

class ServerException extends AppException {
  const ServerException({required super.message})
      : super(statusCode: 500, code: 'SERVER_ERROR');
}
