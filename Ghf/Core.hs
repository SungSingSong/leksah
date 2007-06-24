module Ghf.Core (
    ActionDescr(..)
,   ActionString
,   KeyString

,   Ghf(..)
,   GhfRef
,   GhfM
,   GhfAction
,   GhfPane(..)
,   GhfBuffer(..)

,   Connections(..)
,   FileName
,   Direction(..)
,   PaneDirection(..)
,   PanePath
,   PaneLayout(..)

,   readGhf
,   modifyGhf
,   modifyGhf_
,   withGhf

,   getTopWidget
,   getBufferName
,   getAddedIndex
,   realPaneName

,   helpDebug
) where

import Graphics.UI.Gtk
import Graphics.UI.Gtk.SourceView
import System.Glib.Signals(ConnectId)
import Control.Monad.Reader
import Data.IORef
import System.FilePath
import System.Directory
import System.Console.GetOpt
import System.Environment
import Data.Maybe ( fromMaybe, isJust, fromJust )
import qualified Data.Map as Map
import Data.Map (Map,(!))

data ActionDescr = AD {
                name :: ActionString
            ,   label :: String
            ,   tooltip ::Maybe String
            ,   stockID :: Maybe String
            ,   action :: GhfAction
            ,   accelerator :: [KeyString]
            ,   isToggle :: Bool
} deriving (Show)

type ActionString = String
type KeyString = String


--
-- | The IDE state
--
data Ghf        =   Ghf {
    window      ::  Window
,   uiManager   ::  UIManager
,   panes       ::  Map String GhfPane
,   activePane  ::  Maybe (GhfPane,Connections)
,   paneMap     ::  Map GhfPane (PanePath, [ConnectId Widget])
,   layout      ::  PaneLayout
,   specialKeys ::  Map (KeyVal,[Modifier]) (Map (KeyVal,[Modifier]) ActionDescr)   
,   specialKey  ::  Maybe ((Map (KeyVal,[Modifier]) ActionDescr),String)
} deriving Show

instance Show Window
    where show _ = "Window *"

instance Show Modifier
    where show Shift    = "<shift>"	
          show Control  = "<ctrl>"	
          show Alt      = "<alt>"	
          show Apple    = "<apple>"	
          show Compose  = "<compose>"

instance Show UIManager
    where show _ = "UIManager *"

instance Show (ReaderT a b c)
    where show _ = "ReaderT *"

helpDebug :: GhfAction
helpDebug = do
    ref <- ask
    ghf <- lift $readIORef ref
    lift $do    
        putStrLn $"------------------ "
        putStrLn $show ghf
        putStrLn $"------------------ "

--
-- | Description of the different pane types
--
data GhfPane    =   PaneBuf GhfBuffer
    deriving (Eq,Ord,Show)

getTopWidget :: GhfPane -> Widget
getTopWidget (PaneBuf buf) = castToWidget(scrolledWindow buf)

getBufferName :: GhfPane -> String
getBufferName (PaneBuf buf) = bufferName buf

getAddedIndex :: GhfPane -> Int
getAddedIndex (PaneBuf buf) = addedIndex buf

realPaneName :: GhfPane -> String
realPaneName pane =
    if getAddedIndex pane == 0
        then getBufferName pane
        else getBufferName pane ++ "(" ++ show (getAddedIndex pane) ++ ")"

--
-- | Signal handlers for the different pane types
--
data Connections =  BufConnections [ConnectId SourceView] [ConnectId TextBuffer]
    deriving (Show)

instance Show (ConnectId a)
    where show cid = "ConnectId *"

--
-- | A text editor pane description
--
data GhfBuffer  =   GhfBuffer {
    fileName    ::  Maybe FileName
,   bufferName  ::  String
,   addedIndex  ::  Int
,   sourceView  ::  SourceView 
,   scrolledWindow :: ScrolledWindow
} deriving Show

instance Show SourceView
    where show _ = "SourceView *"

instance Show ScrolledWindow
    where show _ = "ScrolledWindow *"

instance Eq GhfBuffer
    where (==) a b = bufferName a == bufferName b && addedIndex a == addedIndex b

instance Ord GhfBuffer
    where (<=) a b = if bufferName a < bufferName b 
                        then True
                        else if bufferName a == bufferName b 
                            then addedIndex a <= addedIndex b
                            else False


--
-- | The direction of a split
--
data Direction      =   Horizontal | Vertical
    deriving (Eq,Ord,Show)

--
-- | The relative direction to a pane from the parent
--
data PaneDirection  =   TopP | BottomP | LeftP | RightP
    deriving (Eq,Ord,Show)

--
-- | A path to a pane
--
type PanePath       =   [PaneDirection]

--
-- | Logic description of a window layout
--
data PaneLayout =       HorizontalP PaneLayout PaneLayout
                    |   VerticalP PaneLayout PaneLayout
                    |   TerminalP
    deriving (Eq,Ord,Show)


type FileName       =   String

--
-- | A mutable reference to the IDE state
--
type GhfRef = IORef Ghf

--
-- | A reader monad for a mutable reference to the IDE state
--
type GhfM = ReaderT (GhfRef) IO

--
-- | A shorthand for a reader monad for a mutable reference to the IDE state
-- | which does not return a value
--
type GhfAction = GhfM ()

-- | Read an attribute of the contents
readGhf :: (Ghf -> b) -> GhfM b
readGhf f = do
    e <- ask
    lift $ liftM f (readIORef e)

-- | Modify the contents, using an IO action.
modifyGhf_ :: (Ghf -> IO Ghf) -> GhfM ()
modifyGhf_ f = do
    e <- ask
    e' <- lift $ (f =<< readIORef e)
    lift $ writeIORef e e'  

-- | Variation on modifyGhf_ that lets you return a value
modifyGhf :: (Ghf -> IO (Ghf,b)) -> GhfM b
modifyGhf f = do
    e <- ask
    (e',result) <- lift (f =<< readIORef e)
    lift $ writeIORef e e'
    return result

withGhf :: (Ghf -> IO a) -> GhfM a
withGhf f = do
    e <- ask
    lift $ f =<< readIORef e  



