import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:defimnsigner/themes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class Proposal {
  String id;
  String title;
  String github;
  String type;
  bool result = null;

  Proposal({@required this.id, @required this.title, @required this.github, @required this.type});
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
      title: 'DefiChain Masternode DFIP/CFP Signer',
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
      home: MyHomePage(title: 'DefiChain Masternode DFIP/CFP Signer'),
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
        id: 'dfip-2107-b',
        title: 'DFIP 2107-B: Reallocation of block reward for decentralized tokenization incentives',
        github: 'https://github.com/DeFiCh/dfips/issues/50',
        type: 'DFIP'),
    new Proposal(
        id: 'dfip-2107-a',
        title: 'DFIP 2107-A: Introduction of USDC-DFI DEX and reallocation of liquidity mining reward from USDT-DFI',
        github: 'https://github.com/DeFiCh/dfips/issues/49',
        type: 'DFIP'),
    new Proposal(
        id: 'cfp-2107-06',
        title: 'CFP 2107-06: Appreciation for CryptoID Chainz DeFiChain blockchain explorer (15 000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/48',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2107-05',
        title: 'CFP 2107-05: DeFiChain bug bounty fund pre-allocation (20 000 DFI)           ',
        github: 'https://github.com/DeFiCh/dfips/issues/47',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2107-04',
        title: 'CFP 2107-04: defichain-income CFP#2 Long term (20 000 DFI)                   ',
        github: 'https://github.com/DeFiCh/dfips/issues/46',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2107-03',
        title: 'CFP 2107-03: DFI Signal (10 000 DFI)                                          ',
        github: 'https://github.com/DeFiCh/dfips/issues/45',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2107-02',
        title: 'CFP 2107-02: Payment New DefiChain Foundation (21 000 DFI)                     ',
        github: 'https://github.com/DeFiCh/dfips/issues/44',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-2107-01',
        title: 'CFP 2107-01: saiive.live - DeFi Wallet - Light Wallet (40 000 DFI)            ',
        github: 'https://github.com/DeFiCh/dfips/issues/43',
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

  void signMessageCfps() async {
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
                            ElevatedButton(onPressed: _masterNodesLoaded ? signMessageCfps : null, child: Text('Sign'))
                          ])))
                ]),
              )),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final account = dfips[index];
              return new Column(children: [
                Text(account.title),
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
