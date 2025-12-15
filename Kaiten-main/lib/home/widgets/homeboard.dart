import 'package:flutter/material.dart';
import 'package:kaitenapp/contants/colors.dart';

class Homeboard extends StatelessWidget {
  const Homeboard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(

        height: 200,
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
      Positioned(
          top:100,
          left: 50,
          child: Container(
            decoration: BoxDecoration(
                borderRadius:BorderRadius.circular(60),
                color: Colors.white

            ),
            height: 50,
            width: 80,

          )),
      Positioned( top: 40,
          left: 9
          ,child: Image.asset("assets/images/Frame.png",height: 150,width: 150)
      ) ,
      Positioned(top: 110,
          left: 160

          ,child:Container(width:200,child: Text("Welcome to the world's first AI-powered baby care assitant.",style: TextStyle(fontSize: 15,color:Colors.white,fontFamily:"Poppins" )
            ,)
          )
      ),Positioned( top:32,
          left: 172

          ,child:CircleAvatar(radius:35 ,child: Image.asset("assets/images/logo-01.png",height: 150,width: 150),backgroundColor:Colors.white ,)
      ) ,

    ],
    );
  }
}