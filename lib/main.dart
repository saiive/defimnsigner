import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:defimnsigner/themes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_size/window_size.dart';
import 'package:ini/ini.dart';

const String APP_TITLE = "saiive.signer - 2111 DefiChain Masternode DFIP/CFP Signer";

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle(APP_TITLE);
    setWindowMinSize(const Size(700, 500));
    setWindowMaxSize(Size.infinite);
  }

  runApp(MyApp());
}

class Proposal {
  String id;
  String title;
  String github;
  String type;
  bool result = null;

  bool defaultValue = false;

  Proposal({@required this.id, @required this.title, @required this.github, @required this.type, this.defaultValue}) {
    this.result = defaultValue;
  }
}

class LoadingWidget extends StatefulWidget {
  final String text;
  final Stream<String> stream;

  LoadingWidget({@required this.text, this.stream});

  @override
  State<StatefulWidget> createState() {
    return _LoadingWidget();
  }
}

class _LoadingWidget extends State<LoadingWidget> {
  String _text;
  StreamSubscription<String> _textSub;

  void initAsync() async {
    _text = widget.text;

    if (widget.stream != null) {
      _textSub = widget.stream.listen((event) {
        setState(() {
          _text = event;
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initAsync();
  }

  @override
  void dispose() {
    super.dispose();

    if (_textSub != null) {
      _textSub.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.transparent,
        child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(height: 100, width: 100, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
          SizedBox(height: 20),
          Text(this._text ?? '')
        ])));
  }
}

class LoadingOverlay {
  BuildContext _context;
  Stream<String> _loadingText;

  void hide() {
    Navigator.of(_context).pop();
  }

  void show() {
    showDialog(
        context: _context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Container(
              child: Material(
                  type: MaterialType.transparency,
                  child: LoadingWidget(
                    text: 'Loading',
                    stream: _loadingText,
                  )));
        });
  }

  Future<T> during<T>(Future<T> future, {String text}) {
    show();
    return future.whenComplete(() => hide());
  }

  LoadingOverlay._create(this._context, this._loadingText);

  factory LoadingOverlay.of(BuildContext context, {Stream<String> loadingText}) {
    Stream<String> controller;
    if (loadingText == null) {
      // ignore: close_sinks
      var streamController = StreamController<String>();
      streamController.add('Loading');
      controller = streamController.stream;
    } else {
      controller = loadingText;
    }
    var overlay = LoadingOverlay._create(context, controller);
    return overlay;
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    var appTheme = new DefiThemeDark();

    var shadowColor = Colors.transparent;
    var appBarColor = appTheme.lightColor;
    var appBarTextColor = appTheme.primary;
    var appBarActionColor = Colors.transparent;

    ThemeData theme = ThemeData();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: APP_TITLE,
      theme: ThemeData(
          appBarTheme: AppBarTheme(
            backgroundColor: appBarColor,
            shadowColor: shadowColor,
            iconTheme: IconThemeData(color: appBarActionColor),
            foregroundColor: appBarTextColor,
            actionsIconTheme: IconThemeData(color: appBarTextColor),
            toolbarTextStyle: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold),
            titleTextStyle: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold),
            textTheme: theme.textTheme.copyWith(
              headline6: theme.textTheme.headline6.copyWith(color: appBarTextColor, fontSize: 20.0),
            ),
          ),
          brightness: appTheme.brightness,
          primaryColor: appTheme.primary,
          scaffoldBackgroundColor: appTheme.backgroundColor,
          canvasColor: appTheme.backgroundColor,
          textTheme: TextTheme(
              headline3: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: appTheme.text,
              ),
              bodyText1: TextStyle(
                color: appTheme.text,
              ),
              bodyText2: TextStyle(
                color: appTheme.text,
              )),
          buttonColor: appTheme.primary,
          fontFamily: 'Helvetica, Arial, sans-serif',
          tabBarTheme: TabBarTheme(labelColor: appBarTextColor),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(primary: appTheme.primary))),
      home: MyHomePage(title: APP_TITLE),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, @required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _addressController = TextEditingController(text: 'http://127.0.0.1:8555/');
  var _usernameController = TextEditingController(text: '');
  var _passwordController = TextEditingController(text: '');

  Map<int, Widget> _widgets = new Map<int, Widget>();
  var _myMasterNodes = [];
  var _masterNodes = [];
  var _signedMessages = [];
  String _signedText = '';
  String filePathConfig = '';

  bool _masterNodesLoaded = false;

  var dfips = [
    new Proposal(id: 'dfip-2111-a', title: 'DFIP 2111-A: Adding liquidity pool Luna/Dfi', github: 'https://github.com/DeFiCh/dfips/issues/79', type: 'DFIP'),
    new Proposal(
        id: 'dfip-2111-B', title: 'DFIP 2111-B: Vote of confidence: Ethereum Virtual Machine (EVM) Support', github: 'https://github.com/DeFiCh/dfips/issues/96', type: 'CFP'),
    new Proposal(id: 'cfp-2111-01', title: 'CFP 2111-01: defichain-history - Visualize Pool Data (25 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/74', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-02', title: 'CFP 2111-02: Vault and loan monitor with enhanced notifications (45 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/75', type: 'CFP'),
    new Proposal(id: 'cfp-2111-03', title: 'CFP 2111-03: DeFiChain Society Foundation (20 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/76', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-04',
        title: 'CFP 2111-04: Spanish and French translation for Desktop, Mobile APP and Website during 1 year (5 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/77',
        type: 'CFP'),
    new Proposal(id: 'cfp-2111-05', title: 'CFP 2111-05: DFI.TAX (24 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/78', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-06', title: 'CFP 2111-06: saiive.live - New Features (5 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/80', type: 'CFP', defaultValue: true),
    new Proposal(
        id: 'cfp-2111-07',
        title: 'CFP 2111-07: saiive.live iOS/Mac Store Release + Apple Watch (10 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/81',
        type: 'CFP',
        defaultValue: true),
    new Proposal(
        id: 'cfp-2111-08',
        title: 'CFP 2111-08: Establish a Platform for virtual Community Meetups to better connect the Community (20 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/82',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-09',
        title: 'CFP 2111-09: Expansion of the DeFiChain Community to Spanish-speaking countries (5 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/83',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-10',
        title: 'CFP 2111-10: DFX Masternode service – Free of charge on- and off-ramp and automatic transaction service for Masternode operators (60 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/84',
        type: 'CFP'),
    new Proposal(id: 'cfp-2111-11', title: 'CFP 2111-11: DFX Smartphone App (40 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/85', type: 'CFP'),
    new Proposal(id: 'cfp-2111-12', title: 'CFP 2111-12: DeFiChain NFTs for the DeFiChain Community (3 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/86', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-13',
        title: 'CFP 2111-13: Boost the defichain testnet infrastructure for a better testing and improved future product integration testing capabilities (35 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/87',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-14', title: 'CFP 2111-14: DeFined designed - DeFiNode 3D printing service (13 100 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/88', type: 'CFP'),
    new Proposal(id: 'cfp-2111-15', title: 'CFP 2111-15: DefichainGaS" your Giveawayservice (1 500 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/89', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-16',
        title: 'CFP 2111-16: Non-custodial, Decentralised Chain-Interoperability and Funds-Transfer Solution Between DeFiChain and the Ethereum Ecosystem (100 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/90',
        type: 'CFP'),
    new Proposal(id: 'cfp-2111-17', title: 'CFP 2111-17: DeFiChain Promo — January to June 2022 (10 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/91', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-18',
        title: 'CFP 2111-18: IT’S ABOUT MARKETING: making DeFiChain INTERNATIONAL (40 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/92',
        type: 'CFP'),
    new Proposal(id: 'cfp-2111-19', title: 'CFP 2111-19: #roadto50: LET’S MAKE SOME NOISE (5 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/93', type: 'CFP'),
    new Proposal(
        id: 'cfp-2111-20',
        title: 'CFP 2111-20: DeFiChain.Info - News, Social media, Education, Bringing DeFiChain to .NET (20 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/94',
        type: 'CFP'),
    new Proposal(id: 'cfp-2111-21', title: 'CFP 2111-21: DeFiChain Brave Campaign (13 800 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/95', type: 'CFP'),
  ];

  @override
  void initState() {
    super.initState();

    String home = "";
    Map<String, String> envVars = Platform.environment;

    if (Platform.isMacOS) {
      home = envVars['HOME'];
    } else if (Platform.isLinux) {
      home = envVars['HOME'];
    } else if (Platform.isWindows) {
      home = envVars['UserProfile'];
    }

    if (Platform.isMacOS) {
      filePathConfig = home + '/.defi/defi.conf';
    } else if (Platform.isWindows) {
      filePathConfig = home + '/.defi/defi.conf';
    }

    loadConfig();
  }

  void loadConfig() async {
    if (await File(filePathConfig).exists()) {
      new File(filePathConfig).readAsLines().then((lines) => new Config.fromStrings(lines)).then((Config config) => {
            setState(() {
              _usernameController.text = config.defaults()["rpcuser"];
              _passwordController.text = config.defaults()["rpcpassword"];
            })
          });
    }
  }

  void listMasterNodes() async {
    var streamController = StreamController<String>();
    final overlay = LoadingOverlay.of(context, loadingText: streamController.stream);
    overlay.show();

    try {
      streamController.add("loading masternodes...");
      var masterNodes = await createJsonRpcCall('listmasternodes', {
        "pagination": {"including_start": true, "limit": 100000}
      });

      var addresses = await createJsonRpcCall('listaddressgroupings', {});
      var addressList = List<String>.empty(growable: true);

      for (var address in addresses) {
        if (address is List<dynamic>) {
          for (var addressEl in (address as List<dynamic>)) {
            var add = (addressEl as List<dynamic>).first.toString();
            if (add.startsWith("8")) addressList.add(add);
          }
        }
      }

      sleep(Duration(milliseconds: 5));

      setState(() {
        _myMasterNodes = [];
        _signedMessages = [];
        _signedText = '';
      });

      for (var mn in masterNodes.values) {
        var address = mn['ownerAuthAddress'];
        var resignTx = mn['resignTx'];

        _masterNodes.add(mn);
        if (!addressList.contains(address)) {
          continue;
        }

        if (resignTx != "0000000000000000000000000000000000000000000000000000000000000000") {
          continue;
        }

        streamController.add("Check if masternode is ours\n\r($address.)...");
        _myMasterNodes.add(mn);
      }

      setState(() {
        _masterNodes = _masterNodes;
        _myMasterNodes = _myMasterNodes;
        _masterNodesLoaded = true;
      });
    } catch (e) {
      showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: const Text('Error occured'),
                content: Text(e.toString()),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ));
    } finally {
      overlay.hide();
      streamController.close();
      _masterNodesLoaded = true;
    }
  }

  void signMessageCfpsWithAlert() async {
    var import = ElevatedButton(
      child: Text("Ok"),
      onPressed: () async {
        try {
          await signMessageCfps();
        } finally {
          Navigator.of(context).pop();
        }
      },
    );

    AlertDialog alert = AlertDialog(
      title: Center(child: Text("Donate")),
      content: Center(
          child: Column(children: [
        Text("Wanna buy us a coffee? This app is free, but still costs time to maintain ;)\n\n\nSponsor uns doch einen Kaffee ;)"),
        SizedBox(height: 50),
        SelectableText('dResgN7szqZ6rysYbbj2tUmqjcGHD4LmKs'),
      ])),
      actions: [import],
    );
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Future signMessageCfps() async {
    final overlay = LoadingOverlay.of(context);
    overlay.show();

    _signedMessages = [];

    for (var proposal in dfips) {
      _signedMessages.add('=========================');
      _signedMessages.add('');
      _signedMessages.add(proposal.github);
      _signedMessages.add('');
      _signedMessages.add('');
      if (proposal.result != null) {
        for (var mn in _myMasterNodes) {
          var message = proposal.id + "-" + (proposal.result ? "yes" : "no");

          _signedMessages.add('\$ defi-cli signmessage ' + mn['ownerAuthAddress'] + " " + message);
          _signedMessages.add(await signMessage(mn['ownerAuthAddress'], message));
        }
      } else {
        _signedMessages.add('NO VOTE');
        _signedMessages.add('');
      }

      _signedMessages.add('=========================');
    }

    setState(() {
      _signedMessages = _signedMessages;
      _signedText = _signedMessages.join('\n');
    });

    overlay.hide();
  }

  dynamic signMessage(String owner, String message) {
    return createJsonRpcCall("signmessage", [owner, message]);
  }

  dynamic getAddressInfo(String owner) {
    return createJsonRpcCall('getaddressinfo', [owner]);
  }

  dynamic createJsonRpcCall(String method, dynamic params) async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    final address = _addressController.text;
    final basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));
    final uri = Uri.parse(address);

    Map<String, String> headers = {'content-type': 'application/json', 'accept': 'application/json', 'authorization': basicAuth};

    try {
      String stringParams = json.encode(params);

      http.Response response = await http.post(uri, headers: headers, body: '{"jsonrpc": "1.0", "id":"curltest", "method": "$method", "params": $stringParams }');

      final decoded = json.decode(response.body);

      if (null != decoded['error']) {
        return null;
      }

      return decoded['result'];
    } catch (e) {
      throw e;
    }
  }

  openProposalLink(BuildContext context, Proposal proposal) async {
    await launch(proposal.github);
  }

  @override
  Widget build(BuildContext context) {
    var scrollView = CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(10),
              child: Container(
                margin: EdgeInsets.only(top: 10.0),
                child: Row(children: [
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                              height: 300,
                              child: Scrollbar(
                                  child: ListView(shrinkWrap: true, children: [
                                ListView.builder(
                                    physics: BouncingScrollPhysics(),
                                    scrollDirection: Axis.vertical,
                                    shrinkWrap: true,
                                    itemCount: _myMasterNodes.length,
                                    itemBuilder: (context, index) {
                                      var mn = _myMasterNodes.elementAt(index);
                                      return SelectableText(mn['ownerAuthAddress'] ?? '');
                                    })
                              ]))))),
                  Expanded(flex: 1, child: Padding(padding: EdgeInsets.all(10), child: SizedBox(height: 300, child: Scrollbar(child: SelectableText(_signedText))))),
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(children: [
                            Text('Address for donations:'),
                            SelectableText('dResgN7szqZ6rysYbbj2tUmqjcGHD4LmKs'),
                            TextField(
                              controller: _addressController,
                              decoration: InputDecoration(hintText: 'RPC Address'),
                            ),
                            TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(hintText: 'RPC Username'),
                            ),
                            TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(hintText: 'RPC Password'),
                            ),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            ElevatedButton(onPressed: listMasterNodes, child: Text('LoadMasterNodes')),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            ElevatedButton(onPressed: _masterNodesLoaded ? signMessageCfpsWithAlert : null, child: Text('Sign'))
                          ])))
                ]),
              )),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final account = dfips[index];
              return new Column(children: [
                GestureDetector(
                  child: Text(account.title),
                  onTap: () async {
                    await openProposalLink(context, account);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Radio(
                      value: true,
                      groupValue: account.result,
                      onChanged: (var value) {
                        setState(() {
                          account.result = true;
                        });
                      },
                    ),
                    new Text(
                      'Yes',
                      style: new TextStyle(fontSize: 16.0),
                    ),
                    new Radio(
                      value: false,
                      groupValue: account.result,
                      onChanged: (var value) {
                        setState(() {
                          account.result = false;
                        });
                      },
                    ),
                    new Text(
                      'No',
                      style: new TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                )
              ]);
            },
            childCount: dfips.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(10),
              child: Container(
                margin: EdgeInsets.only(top: 10.0),
                child: Column(children: []),
              )),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: LayoutBuilder(builder: (_, builder) {
        return scrollView;
      }),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: Icon(Icons.add),
      // ),
    );
  }
}
