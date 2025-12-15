import 'package:flutter/material.dart';
import 'package:kaitenapp/full_monitoring/screens/fullmonitoring_screen.dart';
class HomePageItem extends StatelessWidget {
  final  String image;
  final  String text;
  const HomePageItem({
    super.key,required this.image ,required this.text
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ()=>  Navigator.push(context, MaterialPageRoute(builder: (context)=>CameraScreen())) ,
      child: Stack(
        children: [Padding(padding: EdgeInsets.symmetric(horizontal: 35),
          child: Container(

            height: 100,
            width: double.infinity,

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0081a7),
                    Color(0xFF0081a7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color(0xFFD0EAFF).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              borderRadius: BorderRadius.only
                (bottomLeft:Radius.circular(200),bottomRight: Radius.circular(200),topLeft: Radius.circular(100),topRight:Radius.circular(100)



                ),


            ),
          ),
        ),

         Positioned( top: 10,
              left: 70
              ,child: CircleAvatar(radius:40,backgroundColor:Colors.white ,backgroundImage: AssetImage(image),)
          ),
          Positioned(
            top:40,
              left:180,

              child: Text(text, style:TextStyle(fontSize: 20,color:Colors.white )
            ,)
          )
        ]
      ),
    );
  }
}