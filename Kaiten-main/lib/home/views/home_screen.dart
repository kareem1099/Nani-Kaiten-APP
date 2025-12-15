import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaitenapp/home/widgets/homeboard.dart';
import '../../contants/colors.dart';
import '../widgets/homepage_item.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFf0ebd8),
                  Color(0xFFf0ebd8),
                ],
              ),
            ),
          ),

          Align(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(0),
                    child: Column(
                      children: [
                        Homeboard(),
                        SizedBox(height: 10),
                        HomePageItem(
                          image: "assets/images/baby.png",
                          text: "Pose Estimation",
                        ),
                        SizedBox(height: 12),
                        HomePageItem(
                          image: "assets/images/monitoring.png",
                          text: "Full Monitoring",
                        ),
                        SizedBox(height: 12),
                        HomePageItem(
                          image: "assets/images/menu-selection.png",
                          text: "Food Guide",
                        ),SizedBox(
                          height: 10,
                        )
                        , Padding(padding: EdgeInsets.symmetric(horizontal: 0),
                          child: Row(
                            children: [
                              Image.asset("assets/images/codifyformatter__4_-removebg-preview 1.png",height:200 ,width: 200),
                              SizedBox(width: 1,),
                              Image.asset("assets/images/codifyformatter__2_-removebg-preview (1).png",height:200 ,width: 200)
                            ],
                          ),
                        ), Spacer()
                        ,Padding(
                          
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 30),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(topRight:Radius.circular(20),topLeft: Radius.circular(20)),
                              color: Color(0xFF0081a7),
                            ),
                            child:Padding(padding:EdgeInsets.symmetric(horizontal: 60),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(onPressed: (){}, icon:Icon(Icons.home,size:40 ,color:Colors.white ,) ),
                                  IconButton(onPressed: (){}, icon: Icon(Icons.history,size: 40,color:Colors.white ,)),
                                  IconButton(onPressed: (){}, icon: Icon(Icons.person,size: 40,color:Colors.white ,),),
                                  IconButton(onPressed: (){}, icon: Icon(Icons.settings,size: 40,color:Colors.white ,))
                              
                                ],
                              ),
                            ) ,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
