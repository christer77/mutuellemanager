/* import 'package:flutter/material.dart';

class ErrorPageScreen extends StatelessWidget {
  static String routeName = "errorPage";
  ErrorPageScreen({Key? key, required this.title, required this.message, required this.routename, required this.error, }) : super(key: key);
  late String? message;
  late String? title;
  late String? routename;
  late String? error;

  @override
  Widget build(BuildContext context) {
    String btnName ="";
    
    switch (error) {
      case 'server-error':
        btnName = "REESSAYER";
        break;
      case 'error-version':
        btnName = "TELECHARGER";
        break;
      default:
        btnName = "RECONNEXION";
    }

    return Scaffold(
      body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/cloud.gif',height: 200,),
              Text(
                title??'SERVEUR INDISPONIBLE ',
                style: textTheme.displayLarge,
              ),
              const Divider(),
              Text(message??"Veuillez vérifier votre connexion internet",
              style:  const TextStyle(
                fontStyle: FontStyle.italic
              ),),

              const SizedBox(height: 10,),
              TextButton(
                child: Text(
                  btnName
                ),
                onPressed: (){
                  if(error =="error-version"){
                    Snackbar.withType( context: context, message: "Veuillez vous mettre à jour", type: 'danger').start();
                  }else{
                    if(routename=='login'){

                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context){
                        
                        return const Login();
                      }), (route) => false,);
                    }
                  }
                  
                 
                },
              )

            ],
          ),
        ),
      )
    ;
  }
}
 */