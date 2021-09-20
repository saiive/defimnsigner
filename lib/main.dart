import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:defimnsigner/themes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_size/window_size.dart';

const String APP_TITLE = "saiive.signer - 2109 DefiChain Masternode DFIP/CFP Signer";

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
  // var _usernameController = TextEditingController(text: 'aRcHsKuR');
  // var _passwordController = TextEditingController(text: 'c29193c17fc12001a1e890a2199b539253b65689cf6980d2aead5e6a7ffd9e88');

  var _usernameController = TextEditingController(text: '');
  var _passwordController = TextEditingController(text: '');

  Map<int, Widget> _widgets = new Map<int, Widget>();
  var _myMasterNodes = [];
  var _masterNodes = [];
  var _signedMessages = [];
  String _signedText = '';

  bool _masterNodesLoaded = false;

  var dfips = [
    new Proposal(
        id: 'cfp-2109-01',
        title: 'CFP 2109-01: Defichain Chrome Extension (13 500 DFI)                             ',
        github: 'https://github.com/DeFiCh/dfips/issues/51',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-02',
        title: 'CFP 2109-02: for moderation and technical improvement concerning the Telegram group: Crypto Steuern DE (585 DFI)                     ',
        github: 'https://github.com/DeFiCh/dfips/issues/52',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-03',
        title: 'CFP 2109-03: DeFined designed - DeFiNode 3D printing service (20 000 DFI)                                          ',
        github: 'https://github.com/DeFiCh/dfips/issues/54',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-04',
        title: 'CFP 2109-04: The DefiMate (39 200 DFI)                                        ',
        github: 'https://github.com/DeFiCh/dfips/issues/56',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-05',
        title: 'CFP 2109-05: Telegram Moderators (5 500 DFI)                                   ',
        github: 'https://github.com/DeFiCh/dfips/issues/57',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-06',
        title: 'CFP 2109-06: „Promotion tools“ (1 500 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/58',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-07',
        title: 'CFP 2109-07: Defilinks.io - the Gateway into the DeFiChain Universe (20 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/59',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-08',
        title: 'CFP 2109-08: Masternode Health (5 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/60',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-09',
        title: 'CFP 2109-09: DeFiChain WebWallet (65 772 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/61',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-10',
        title: 'CFP 2109-10: DefiChain YouTube formats (DeFiChain News Team) (20 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/62',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-11',
        title: 'CFP 2109-11: Defichain helps decarbonizing Defichain (20 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/63',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-12',
        title: 'CFP 2109-12: DeFiChain Value - Be ahead, follow the strategies (16 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/65',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-13',
        title: 'CFP 2109-13: DFX Smartphone App (26 000 DFI)                                    ',
        github: 'https://github.com/DeFiCh/dfips/issues/66',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-14',
        title: 'CFP 2109-14: DeFiChain Master Noder Signer (6 000 DFI)                                     ',
        github: 'https://github.com/DeFiCh/dfips/issues/68',
        type: 'CFP',
        defaultValue: true),
    new Proposal(
        id: 'cfp-2109-15',
        title: 'CFP 2109-15: saiive.live - Jellyfish Compatibility (5 000 DFI)                                     ',
        github: 'https://github.com/DeFiCh/dfips/issues/69',
        type: 'CFP',
        defaultValue: true),
    new Proposal(
        id: 'cfp-2109-16',
        title: 'CFP 2109-16: DFX - Decentralized Finance Exchange (135 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/70',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-17',
        title: 'CFP 2109-17: DeFiChain Accelerator (50 000 DFI)                                      ',
        github: 'https://github.com/DeFiCh/dfips/issues/71',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2109-18',
        title: 'CFP 2109-18: DeFiChain Networkmap (1 893 DFI)                                     ',
        github: 'https://github.com/DeFiCh/dfips/issues/72',
        type: 'CFP')
  ];

  @override
  void initState() {
    super.initState();
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
