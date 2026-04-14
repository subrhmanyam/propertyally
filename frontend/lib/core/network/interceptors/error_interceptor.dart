import 'package:dio/dio.dart';
import '../../exceptions/app_exception.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = _mapError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
        message: appException.message,
        type: err.type,
        response: err.response,
      ),
    );
  }

  AppException _mapError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();

      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'No internet connection. Please check your network.',
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        if (statusCode == 401) {
          return const UnauthorizedException();
        } else if (statusCode == 404) {
          return const NotFoundException(message: 'The requested resource was not found.');
        } else if (statusCode >= 500) {
          return const ServerException(message: 'A server error occurred. Please try again later.');
        }
        return AppException(
          message: err.response?.data?['message']?.toString() ?? 'An unexpected error occurred.',
          statusCode: statusCode,
        );

      default:
        return AppException(
          message: err.message ?? 'An unexpected error occurred.',
        );
    }
  }
}
