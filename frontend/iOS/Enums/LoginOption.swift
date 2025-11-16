//
//  LoginOption.swift
//  VibeZ iOS
//
//  Login option types
//

enum LoginOption {
	case signInWithApple
	case signInWithGoogle
	case emailAndPassword(email: String, password: String)
}

