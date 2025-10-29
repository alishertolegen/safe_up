import 'package:flutter/material.dart';

void main() => runApp(TestPage());

class TestPage extends StatelessWidget{
  String example = "example";

  @override
  Widget build(BuildContext build){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text("APPBAR", style: TextStyle(color: Colors.white),),backgroundColor: Colors.black,),
        body: Center(
         child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Example $example"),
            ElevatedButton(onPressed: () {}, child: Text("BUTTON"))
          ],
         ),
        ),
      ),
    );
  }
}