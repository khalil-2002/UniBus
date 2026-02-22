import 'package:flutter/material.dart';

class MyTransparentTextField extends StatefulWidget {
  final IconData prefixIcon;
  final String labeltext;
  final String hinttext;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final TextInputAction textInputAction;

  const MyTransparentTextField({
    super.key,
    this.controller,
    this.prefixIcon = Icons.fiber_manual_record_rounded,
    this.labeltext = "Pas de label",
    this.hinttext = "Pas de hint",
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
  });

  @override
  State<MyTransparentTextField> createState() => _MyTransparentTextFieldState();
}

class _MyTransparentTextFieldState extends State<MyTransparentTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscureText : false,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: Icon(widget.prefixIcon, color: Colors.white, size: 30),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
          label: Text(
            widget.labeltext,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
          hintText: widget.hinttext,
          hintStyle: const TextStyle(
            color: Colors.white60,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
