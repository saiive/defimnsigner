import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:defimnsigner/themes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_size/window_size.dart';
import 'package:ini/ini.dart';

const String APP_TITLE = "saiive.signer - 2202 DefiChain Masternode DFIP/CFP Signer";

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
  Votes result = Votes.NO_VOTE;

  Votes defaultValue = Votes.NO_VOTE;

  Proposal({@required this.id, @required this.title, @required this.github, @required this.type, this.defaultValue = Votes.NO_VOTE}) {
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

enum Votes { YES, NO, NEUTRAL, NO_VOTE }

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
    new Proposal(id: 'dfip-2203-a', title: 'DFIP-2203-A: Solving dToken premium via future contracts', github: 'https://github.com/DeFiCh/dfips/issues/127', type: 'DFIP'),
    new Proposal(id: 'dfip-2203-b', title: 'DFIP-2203-B: Vault | Adding Ethereum as collateral for vaults', github: 'https://github.com/DeFiCh/dfips/issues/109', type: 'DFIP'),
    new Proposal(id: 'cfp-2203-01', title: 'CFP-2203-01: Public REST API For Historical DEX Prices (2 600 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/125', type: 'CFP'),
    new Proposal(
        id: 'cfp-2203-02',
        title: 'CFP-2203-02: For moderation concerning the Telegram group: Crypto Steuern DACH (ENG/DE) (1 510 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/126',
        type: 'CFP'),
    new Proposal(id: 'cfp-2203-03', title: 'CFP-2203-03: AlkCoin for DefiChain (0 DFI) ', github: 'https://github.com/DeFiCh/dfips/issues/129', type: 'CFP'),
    new Proposal(id: 'cfp-2203-04', title: 'CFP-2203-04: DeFiChain Community Blog (650 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/130', type: 'CFP'),
    new Proposal(
        id: 'cfp-2203-05',
        title: 'CFP-2203-05: DeFiChain Captain - New features + ongoing maintenance (4 500 DFI) ',
        github: 'https://github.com/DeFiCh/dfips/issues/131',
        type: 'CFP'),
    new Proposal(id: 'cfp-2203-06', title: 'CFP-2203-06: DefiChain Sports App (189500 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/132', type: 'CFP'),
    new Proposal(id: 'cfp-2203-07', title: 'CFP-2203-07: DeFiChain Python Library (1 800 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/133', type: 'CFP'),
    new Proposal(id: 'cfp-2203-08', title: 'CFP-2203-08: Defichain-Ecosystem (2 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/134', type: 'CFP'),
    new Proposal(id: 'cfp-2203-09', title: 'CFP-2203-09: Extending Dobby with phone notifications (30 000 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/136', type: 'CFP'),
    new Proposal(id: 'cfp-2203-10', title: 'CFP-2203-10: Masternode Monitor 2.0 (12 500 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/137', type: 'CFP'),
    new Proposal(id: 'cfp-2203-11', title: 'CFP: Moonrize - Reddit Posting Bot (8 753 DFI)', github: 'https://github.com/DeFiCh/dfips/issues/138', type: 'CFP')
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
            if (add.startsWith('8')) addressList.add(add);
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

      overlay.hide();
      streamController.close();
    } catch (e) {
      overlay.hide();
      streamController.close();
      _masterNodesLoaded = true;
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
    } finally {}
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
      if (proposal.result == Votes.NO_VOTE) {
        continue;
      }

      _signedMessages.add('=========================');
      _signedMessages.add('');
      _signedMessages.add(proposal.id + ': ' + proposal.github);
      _signedMessages.add('');
      _signedMessages.add('');
      for (var mn in _myMasterNodes) {
        var result = "yes";

        if (proposal.result == Votes.YES) {
          result = "yes";
        } else if (proposal.result == Votes.NO) {
          result = "no";
        } else if (proposal.result == Votes.NEUTRAL) {
          result = "neutral";
        }

        var message = proposal.id + "-" + result;

        _signedMessages.add('\$ defi-cli signmessage ' + mn['ownerAuthAddress'] + " " + message);
        _signedMessages.add(await signMessage(mn['ownerAuthAddress'], message));
      }

      _signedMessages.add('=========================');
    }
    _signedText = _signedMessages.join('\n');

    AlertDialog resultDialog = AlertDialog(
        title: Center(child: Text("Sign Result")),
        content: Center(
            child: Column(children: [
          Expanded(flex: 1, child: Padding(padding: EdgeInsets.all(10), child: SizedBox(height: 300, child: SingleChildScrollView(child: SelectableText(_signedText)))))
        ])),
        actions: [
          ElevatedButton(
            child: Text("Close"),
            onPressed: () async {
              Navigator.of(context).pop();
            },
          )
        ]);

    overlay.hide();

    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return resultDialog;
      },
    );
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

  allVotes(Votes vote) {
    setState(() {
      dfips.forEach((element) {
        element.result = vote;
      });
    });
  }

  openProposalLink(BuildContext context, Proposal proposal) async {
    await launch(proposal.github);
  }

  @override
  Widget build(BuildContext context) {
    var body = FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                  height: MediaQuery.of(context).size.height,
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.only(top: 10, left: 10, right: 10),
                            child: Row(children: [
                              ElevatedButton(onPressed: () => {allVotes(Votes.YES)}, child: Text('All YES')),
                              Container(width: 5),
                              ElevatedButton(onPressed: () => {allVotes(Votes.NO)}, child: Text('All NO')),
                              Container(width: 5),
                              ElevatedButton(onPressed: () => {allVotes(Votes.NEUTRAL)}, child: Text('All Neutral')),
                              Container(width: 5),
                              ElevatedButton(onPressed: () => {allVotes(Votes.NO_VOTE)}, child: Text('All NO VOTE')),
                            ]))),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final account = dfips[index];
                          return Padding(
                              padding: EdgeInsets.all(10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                GestureDetector(
                                  child: Text(' (' + account.id + ') ' + account.title),
                                  onTap: () async {
                                    await openProposalLink(context, account);
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[
                                    new Radio(
                                      value: Votes.YES,
                                      groupValue: account.result,
                                      onChanged: (var value) {
                                        setState(() {
                                          account.result = Votes.YES;
                                        });
                                      },
                                    ),
                                    new Text(
                                      'Yes',
                                      style: new TextStyle(fontSize: 16.0),
                                    ),
                                    new Radio(
                                      value: Votes.NO,
                                      groupValue: account.result,
                                      onChanged: (var value) {
                                        setState(() {
                                          account.result = Votes.NO;
                                        });
                                      },
                                    ),
                                    new Text(
                                      'No',
                                      style: new TextStyle(
                                        fontSize: 16.0,
                                      ),
                                    ),
                                    new Radio(
                                      value: Votes.NEUTRAL,
                                      groupValue: account.result,
                                      onChanged: (var value) {
                                        setState(() {
                                          account.result = Votes.NEUTRAL;
                                        });
                                      },
                                    ),
                                    new Text(
                                      'Neutral',
                                      style: new TextStyle(
                                        fontSize: 16.0,
                                      ),
                                    ),
                                    new Radio(
                                      value: Votes.NO_VOTE,
                                      groupValue: account.result,
                                      onChanged: (var value) {
                                        setState(() {
                                          account.result = Votes.NO_VOTE;
                                        });
                                      },
                                    ),
                                    new Text(
                                      'No Vote',
                                      style: new TextStyle(
                                        fontSize: 16.0,
                                      ),
                                    ),
                                  ],
                                )
                              ]));
                        },
                        childCount: dfips.length,
                      ),
                    )
                  ])),
            ),
            LimitedBox(
              maxWidth: 350,
              child: Container(
                  height: MediaQuery.of(context).size.height,
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.all(10),
                            child: FocusTraversalOrder(
                                order: NumericFocusOrder(2.0),
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
                                  ElevatedButton(onPressed: _masterNodesLoaded && _myMasterNodes.length > 0 ? signMessageCfpsWithAlert : null, child: Text('Sign'))
                                ])))),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Your Masternodes', style: Theme.of(context).textTheme.headline3),
                              _myMasterNodes.length > 0
                                  ? ListView(shrinkWrap: true, children: [
                                      ListView.builder(
                                          physics: BouncingScrollPhysics(),
                                          scrollDirection: Axis.vertical,
                                          shrinkWrap: true,
                                          itemCount: _myMasterNodes.length,
                                          itemBuilder: (context, index) {
                                            var mn = _myMasterNodes.elementAt(index);
                                            return SelectableText(mn['ownerAuthAddress'] ?? '');
                                          })
                                    ])
                                  : Text('No Masternods found')
                            ])))
                  ])),
            ),
          ],
        ));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: LayoutBuilder(builder: (_, builder) {
        return body;
      }),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: Icon(Icons.add),
      // ),
    );
  }
}
