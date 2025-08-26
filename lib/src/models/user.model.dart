import 'dart:convert';

class User {
  String user;
  String password;
  // Can be a single embedding (List<num>) or list of embeddings (List<List<num>>)
  List modelData;

  User({required this.user, required this.password, required this.modelData});

  static User fromMap(Map<String, dynamic> user) {
    return User(
      user: user['user'],
      password: user['password'],
      modelData: jsonDecode(user['model_data']),
    );
  }

  toMap() {
    return {
      'user': user,
      'password': password,
      'model_data': jsonEncode(modelData),
    };
  }
}
