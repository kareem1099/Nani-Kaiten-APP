import 'package:flutter/material.dart';
import 'package:kaitenapp/contants/colors.dart';

class Pageboard extends StatelessWidget {
  const Pageboard({super.key});

  @override
  Widget build(BuildContext context) {
    return  Stack(children: [
      Container(

        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: myColors.myPrimarycolor,
          borderRadius: BorderRadius.only(bottomLeft:Radius.circular(150),bottomRight: Radius.circular(150),


          ),
        ),
        child: Card(
          elevation: 20,
          color:Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(bottomLeft:Radius.circular(150),bottomRight: Radius.circular(150))
          ),
          child: SizedBox.expand(),
        ),
      ),

      Positioned( top:32,
          left: 172

          ,child:CircleAvatar(radius:35 ,child: Image.asset("assets/images/logo-01.png",height: 250,width: 250),backgroundColor:Colors.white ,)
      ) ,

    ],
    );
  }
}
