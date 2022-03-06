import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Auth with ChangeNotifier{

  String? _token ;
  DateTime? _expiryDate;
  String? _userId ;
  Timer? _authTimer ;

  bool get isAuth  {
    return token != null;
}
String? get  token{
    if(_expiryDate != null && _expiryDate!.isAfter(DateTime.now()) && _token != null){
      return _token;
    }else{
      return null;
    }
}

  Future<void> _authenticate (String email,String password,String urlSegment)async{
    final url = 'https://identitytoolkit.googleapis.com/v1'
        '/accounts:$urlSegment?key=AIzaSyClqcY6t1_PTH07HSZSYykPibhdjR8xwiM';

    try{
      final res = await http.post(Uri.parse(url),body: json.encode({
        'email':email,
        'password':password,
        'returnSecureToken':true,
      }));
      final resdata =json.decode(res.body);
      if(resdata['error'] != null){
        throw '${resdata['error']['message']}';
      }
      _token = resdata['idToken'];
      _userId = resdata['localId'];
      _expiryDate = DateTime.now().add(Duration(seconds: int.parse(resdata['expiresIn'])));

      autoLogout();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode({
        'token':_token,
        'userId':_userId,
        'expiryDate':_expiryDate!.toIso8601String(),
      });
      
      prefs.setString('userData', userData);

    }catch(e){
      throw e;
    }

  }

  Future<bool> tryAutoLogin()async{
    final prefs = await SharedPreferences.getInstance();
    if(!prefs.containsKey('userData')){
      return false;
    }
  final extractedUserData =  json.decode(prefs.getString('userData')!) as Map<String,Object>;
    final expiryDate = DateTime.parse(extractedUserData['expiryDate']as String);
    if(expiryDate.isBefore(DateTime.now())){
      return false;
    }
    _token = extractedUserData['token'] as String;
    _userId = extractedUserData['_userId'] as String;
    _expiryDate = expiryDate;
    notifyListeners();
    autoLogout();
    return true;
  }

  Future<void> signUp (String email,String password)async{
   return _authenticate(email, password,'signUp' );
  }

  Future<void> login (String email,String password)async{
    return _authenticate(email, password,'signInWithPassword' );
  }

 Future<void> logout() async{
    _token = null;
    _userId = null;
    _expiryDate = null;
    if(_authTimer != null){
      _authTimer!.cancel();
      _authTimer= null;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
     prefs.clear(); // prefs.remove('userData');

 }

  void autoLogout(){
    if(_authTimer != null){
      _authTimer!.cancel();
    }
    final timeToExpiry = _expiryDate!.difference(DateTime.now()).inSeconds;
    _authTimer =  Timer(Duration(seconds: timeToExpiry),() => logout());
    notifyListeners();
  }


}